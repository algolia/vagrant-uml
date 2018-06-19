require 'vagrant/util/subprocess'
require 'vagrant-uml/process'
require 'tmpdir'
require 'fileutils'
require 'ipaddr'

module VagrantPlugins
  module UML
    class CLI
      # Group all functions that will call external commands here.

      attr_accessor :name

      def initialize(name = nil)
        @name = name
        @tunctl_path = Vagrant::Util::Which.which('tunctl')
        @mconsole_path = Vagrant::Util::Which.which('uml_mconsole')
        @switch_path = Vagrant::Util::Which.which('uml_switch')
        @logger = Log4r::Logger.new('vagrant::uml::cli')
      end

      def full_sudo_allowed?
        # Check that the user is "full" sudoer
        res = Vagrant::Util::Subprocess.execute('sudo', '-l')
        return true if res.stdout =~ /[[:blank:]]*\(ALL\) NOPASSWD: ALL/
        false
      end

      def sudo_allowed?
        # Lets figure out if the user already added the sudo rules generated from `vagrant uml-sudoer`
        regex = <<~REGEX
          \s+\\\(root\\\) NOPASSWD: \/usr\/sbin\/tunctl -u #{ENV['USER']} -t uml-\\\[a-zA-Z0-9\\\]\\\*
          \s+\\\(root\\\) NOPASSWD: \/sbin\/sysctl -w net\.ipv4.ip_forward\\\\=1
          \s+\\\(root\\\) NOPASSWD: \/sbin\/ifconfig uml-\\\[a-zA-Z0-9\\\]\\\* \\\[0-9.\\\]\\\*\/30 up
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -t nat -A POSTROUTING -s \\\[0-9\\\.\\\]\\\* -o \\\[a-zA-Z0-9\\\-\\\.\\\]\\\* -m comment --comment uml-\\\[a-zA-Z0-9\\\]\\\* -j MASQUERADE
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -I FORWARD -i \\\[a-zA-Z0-9\\\-\\\.\\\]\\\*  -o \\\[a-zA-Z0-9\\\-\\\.\\\]\\\* -m comment --comment \\\[-a-zA-Z0-9\\\]\\\* -j ACCEPT
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -t nat -L POSTROUTING --line-numbers -n
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -L FORWARD --line-numbers -n
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -t nat -D POSTROUTING \\\[0-9\\\]\\\*
          \s+\\\(root\\\) NOPASSWD: \/sbin\/iptables -D FORWARD \\\[0-9\\\]\\\*
          \s+\\\(root\\\) NOPASSWD: \/sbin\/ip link delete uml-\\\[a-zA-Z0-9\\\]\\\*
        REGEX
        res = Vagrant::Util::Subprocess.execute('sudo', '-l')
        return true if res.stdout =~ /#{regex}/
        false
      end

      # This is meant to ensure that the mconsole socket for an instance
      # exists as UML takes 1 or seconds to create it after starting
      def wait_for_running(id)
        begin
          Timeout.timeout(30) do
            loop do
              begin
                res = Vagrant::Util::Subprocess.execute(@mconsole_path, id, 'version', timeout: 1)
                return true if res.stdout =~ /^OK/
                sleep 0.5
              rescue Vagrant::Util::Subprocess::TimeoutExceeded
                sleep 0.5
              end
            end
          end
        rescue Timeout::Error
          # We timeout, there is probably an issue in starting this instance ...
          return false
        end
      end

      def state(id)
        # Lets use the mconsole to detect the status: if the mconsole "version" command returns
        #  returns a result this means the machine is running, else it's not
        return :unknown unless @name
        begin
          res = Vagrant::Util::Subprocess.execute(@mconsole_path, id, 'version', timeout: 1)
          if res.stdout =~ /^OK/
            @logger.debug('instance is running')
            return :running
          else
            return :poweroff
          end
        rescue Vagrant::Util::Subprocess::TimeoutExceeded
          ## We should try to figure out if the machine is stopped, not_created, ...
          #   test if the cow file exists ?
          @logger.debug('instance state unknown error during call to uml_mconsole')
          return :unknown
        end
      end

      # Create a VFAT seed image for cloud-init in order to have the guest
      #  correctly configured. The following is done through cloud-init:
      #   - network config (eth0)
      #   -  hostname set
      #   - vagrant user creation
      #   - /vagrant hostfs mount
      def create_cidata(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}

        @logger.debug("root_path = #{options[:root_path]}")
        # We may use guestfs bindings, but ruby-guests requires a lot of dependencies ...
        mkfs = Vagrant::Util::Which.which('mkfs.vfat')
        mcopy = Vagrant::Util::Which.which('mcopy')

        guest_ip = IPAddr.new(options[:host_ip].to_s).succ.to_s

        # The user-data to provide to cloud-init
        ud_template = <<EOS
#cloud-config
chpasswd: { expire: False }
ssh_pwauth: True
groups:
  - vagrant
users:
  - name: vagrant
    primary_group: vagrant
    groups: users vagrant
    passwd: $6$6aBk4uhH$zDKLrsc94Xg1eSy4yIIi/7oKvW34YjnAKzuf7.wUvM.5VJhJsf2M97oOUdQQ0hooRz508iXKPxTRf7H8EWJPx0
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: False
    ssh_authorized_keys:
      - #{Vagrant.source_root.join('keys', 'vagrant.pub').read.chomp}
runcmd:
  - [ 'sh', '-xc', "[ ! -d /vagrant ] && mkdir /vagrant || true" ]
mounts:
  - [ "none", "/vagrant", "hostfs", "#{options[:root_path]}", "0", "2" ]
manage_etc_hosts: true
hostname: #{options[:name]}
fqdn: #{options[:name]}
EOS

        # the network-config data
        net_template = <<EOS
---
version: 1
config:
  - type: physical
    name: eth0
    mac_address: "#{options[:mac]}"
    subnets:
      - type: static
        address: #{guest_ip}
        netmask: 255.255.255.252
        gateway: #{options[:host_ip]}
  - type: nameserver
    address:
      - 8.8.8.8
EOS
        # create a temporary directory that will handle the files to insert in the cloud-init seed
        Dir.mktmpdir do |dir|
          File.open("#{dir}/meta-data", 'w') do |f|
            f.write("instance-id: #{options[:machine_id]}\n")
            f.write('dsmode: local')
          end
          File.open("#{dir}/user-data", 'w') do |f|
            f.write(ud_template)
          end
          File.open("#{dir}/network-config", 'w') do |f|
            f.write(net_template)
          end
          # create the vfat fs file for seed destination
          Vagrant::Util::Subprocess.execute('truncate',
            '--size',
            '100K',
            "#{dir}/cloud-init.vfat",
            retryable: true)
          Vagrant::Util::Subprocess.execute(mkfs,
            '-n',
            'cidata',
            "#{dir}/cloud-init.vfat",
            retryable: true)
          Vagrant::Util::Subprocess.execute(mcopy,
            '-oi',
            "#{dir}/cloud-init.vfat",
            "#{dir}/meta-data",
            "#{dir}/user-data",
            "#{dir}/network-config",
            '::',
            retryable: true,
            env: [['MTOOLS_SKIP_CHECK', '1']])
          FileUtils.mv("#{dir}/cloud-init.vfat", "#{options[:data_dir]}/cloud-init.vfat")
        end
      end

      # Run the UML kernel with all the options
      def run_uml(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}
        command = command.dup

        # umdir should probably be set to data_dir to prevent zombies sockets
        process = Process.new(command[0],
          "ubda=cow,#{options[:rootfs]}",
          'ubdb=cloud-init.vfat',
          "umid=#{options[:machine_id]}",
          "mem=#{options[:mem]}m",
          "eth0=#{options[:eth0]}",
          "con0=#{options[:con0]}",
          "con1=#{options[:con1]}",
          "ncpus=#{options[:ncpus]}",
          "con=#{options[:con]}",
          "ssl=#{options[:ssl]}",
          detach: true,
          workdir: options[:data_dir])
        process.run
      end

      def create_switched_net(options)
      end

      # Create all the network ressources to be used by the UML instance
      #  thats the most painfull/dirty part cause it uses privileged commands
      #  and for now restricts the usage of this provider to root or sudoers
      def create_standalone_net(options)
        # use a /30 network for the tuntap with guest_ip=host_ip+1
        guest_ip = IPAddr.new(options[:host_ip].to_s).succ.to_s

        # Create the tuntap device and check it worked
        res = Vagrant::Util::Subprocess.execute('sudo',
          @tunctl_path,
          '-u',
          ENV['USER'],
          '-t',
          "uml-#{options[:name]}",
          retryable: true)
        res.stdout =~ /Set 'uml-(.+?)' persistent and owned by uid (.+?)/
        raise 'TUN/TAP interface name mismatch !' if $1.to_s != options[:name]
        # Set the ip address of the tuntap device on host side
        Vagrant::Util::Subprocess.execute('sudo',
          'ifconfig',
          "uml-#{options[:name]}",
          "#{options[:host_ip]}/30",
          'up',
          retryable: true)

        # get the default gateway interface (we'll apply some nat rules on it later)
        res = Vagrant::Util::Subprocess.execute('ip',
          '-4',
          'route',
          'list',
          'match',
          '0.0.0.0',
          retryable: true)
        res.stdout =~ /default via ([0-9.]+) dev (\S+)(\s+\S+)*/
        default_interface = $2.to_s

        # allow ip forwarding to ensure the guest will have access to outside world
        Vagrant::Util::Subprocess.execute('sudo',
          'sysctl',
          '-w',
          'net.ipv4.ip_forward=1',
          retryable: true)

        # Create a MASQUERADING rule for the guest to be able to reach the rest of the world
        # using the host as NAT gateway
        # Use the comment iptable match to ensure a rule belongs to a specific instance
        Vagrant::Util::Subprocess.execute('sudo',
          'iptables',
          '-t',
          'nat',
          '-A',
          'POSTROUTING',
          '-s',
          guest_ip,
          '-o',
          default_interface,
          '-m',
          'comment',
          '--comment',
          options[:name],
          '-j',
          'MASQUERADE',
          retryable: true)

        # Allow forwarding to/from the UML instance
        Vagrant::Util::Subprocess.execute('sudo',
          'iptables',
          '-I',
          'FORWARD',
          '-i',
          "uml-#{options[:name]}",
          '-o',
          default_interface,
          '-m',
          'comment',
          '--comment',
          "from-#{options[:name]}",
          '-j',
          'ACCEPT')
        Vagrant::Util::Subprocess.execute('sudo',
          'iptables',
          '-I',
          'FORWARD',
          '-i',
          default_interface,
          '-o',
          "uml-#{options[:name]}",
          '-m',
          'comment',
          '--comment',
          "to-#{options[:name]}",
          '-j',
          'ACCEPT')
      end


      def destroy_standalone_net(id)
        # Clean the MASQUERADE rule created for this instance id, it has tagged in its comment
        # with the id
        # List all existing NAT POSTROUTING rules and parse
        res = Vagrant::Util::Subprocess.execute('sudo',
          'iptables',
          '-t',
          'nat',
          '-L',
          'POSTROUTING',
          '--line-numbers',
          '-n',
          retryable: true)
        res.stdout =~ /([0-9]+)\s+MASQUERADE\s+all\s+--\s+[0-9.]+\s+0\.0\.0\.0\/0\s+\/\*\s+#{id}\s+\*\//
        rule_number = $1.to_s
        if rule_number && !rule_number.empty?
          # Clean it based on its rule number (if it exists)
          Vagrant::Util::Subprocess.execute('sudo',
            'iptables',
            '-t',
            'nat',
            '-D',
            'POSTROUTING',
            rule_number,
            retryable: true)
        end

        # Clean the forwarding rules
        ['to','from'].each do |direction|
          res = Vagrant::Util::Subprocess.execute('sudo',
            'iptables',
            '-L',
            'FORWARD',
            '--line-numbers',
            '-n',
            retryable: true)
          res.stdout =~ /([0-9]+)\s+ACCEPT\s+all\s+--\s+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0\s+\/\*\s+#{direction}-#{id}\s+\*\//
          rule_number = $1.to_s
          if rule_number && !rule_number.empty?
            # Clean it based on its rule number (if it exists)
            Vagrant::Util::Subprocess.execute('sudo',
              'iptables',
              '-D',
              'FORWARD',
              rule_number,
              retryable: true)
          end
        end

        # Now deletes the tuntap device
        Vagrant::Util::Subprocess.execute('sudo',
          'ip',
          'link',
          'delete',
          "uml-#{id}",
          retryable: true)
      end
    end
  end
end
