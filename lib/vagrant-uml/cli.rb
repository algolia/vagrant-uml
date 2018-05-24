require "vagrant/util/subprocess"
require "vagrant-uml/process"
require "tmpdir"
require "fileutils"

module VagrantPlugins
  module UML
    class CLI
      attr_accessor :name

      def initialize(name = nil)
        @name = name
        @tunctl_path = Vagrant::Util::Which.which("tunctl")
        @mconsole_path = Vagrant::Util::Which.which("uml_mconsole")
        @switch_path = Vagrant::Util::Which.which("uml_switch")
        @logger = Log4r::Logger.new("vagrant::uml::cli")
      end

      def state(id)
        if !@name
          return :unknown
        else
          begin
            res = Vagrant::Util::Subprocess.execute(@mconsole_path, id, "version", retryable: true)
            if res.stdout =~ /^OK/
              @logger.debug( "Cli.state: instance is running")
              return :running
            else
              return :poweroff
            end
          rescue
            ## We should try to figure out if the machine is stopped, not_created, ...
            #   test if the cow file exists ?
            @logger.debug( "Cli.state: RESCUE instance state unknown error during call to uml_mconsole")
            return :unknown
          end
        end
      end

      def create_cidata(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}

        @logger.debug( "Cli.cidata: root_path = #{options[:root_path]}")
        # We may use guestfs bindings, but ruby-guests requires a lot of dependencies ...
        mkfs = Vagrant::Util::Which.which("mkfs.vfat")
        mcopy = Vagrant::Util::Which.which("mcopy")

# env[:machine].config.vm.hostname

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
      - #{Vagrant.source_root.join("keys", "vagrant.pub").read.chomp}
runcmd:
  - [ 'sh', '-xc', "[ ! -d /vagrant ] && mkdir /vagrant || true" ]
mounts:
  - [ "none", "/vagrant", "hostfs", "#{options[:root_path]}", "0", "2" ]
manage_etc_hosts: true
hostname: #{options[:name]}
fqdn: #{options[:name]}
EOS

        net_template = <<EOS
---
version: 1
config:
  - type: physical
    name: eth0
    mac_address: "#{options[:mac]}"
    subnets:
      - type: static
        address: 192.168.0.2
        netmask: 255.255.255.0
        gateway: 192.168.0.1
  - type: nameserver
    address:
      - 8.8.8.8
EOS
        Dir.mktmpdir {|dir|
          open("#{dir}/meta-data","w") do |f|
            f.write("instance-id: #{options[:machine_id]}\n")
            f.write("dsmode: local")
          end
          open("#{dir}/user-data","w") do |f|
            f.write(ud_template)
          end
          open("#{dir}/network-config","w") do |f|
            f.write(net_template)
          end
          Vagrant::Util::Subprocess.execute("truncate", "--size", "100K", "#{dir}/cloud-init.vfat", retryable: true)
          Vagrant::Util::Subprocess.execute(mkfs,"-n", "cidata", "#{dir}/cloud-init.vfat", retryable: true)
          Vagrant::Util::Subprocess.execute(mcopy,"-oi", "#{dir}/cloud-init.vfat", "#{dir}/meta-data", "#{dir}/user-data", "#{dir}/network-config","::", retryable: true)
          FileUtils.mv("#{dir}/cloud-init.vfat", "#{options[:data_dir]}/cloud-init.vfat")
        }
      end


      def run_uml(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}
        command = command.dup

        # umdir should probably be set to data_dir to prevent zombies sockets 
        process = Process.new(
          command[0],
          "ubda=cow,#{options[:rootfs]}" ,
          "ubdb=cloud-init.vfat" ,
          "umid=#{options[:machine_id]}" ,
          "mem=#{options[:mem]}m" ,
          "eth0=#{options[:eth0]}" ,
          "con0=#{options[:con0]}",
          "con1=#{options[:con1]}",
          "ncpus=#{options[:ncpus]}",
          "con=#{options[:con]}",
          "ssl=#{options[:ssl]}",
          :detach => true ,
          :workdir => options[:data_dir]
        )
        process.run 
      end

      def create_switched_net(options)
      end

      def create_standalone_net(options)
         res = Vagrant::Util::Subprocess.execute(@tunctl_path, "-t", options[:name], retryable: true)
         res.stdout =~ /Set '(.+?)' persistent and owned by uid (.+?)/
         if $1.to_s != options[:name]
           raise "TUN/TAP interface name mismatch !"
         end
         Vagrant::Util::Subprocess.execute("ifconfig", options[:name], options[:host_ip]+"/24", "up", retryable: true)
         Vagrant::Util::Subprocess.execute("sysctl", "-w", "net.ipv4.ip_forward=1", retryable: true)
         Vagrant::Util::Subprocess.execute("iptables", "-t", "nat", "-A" , "POSTROUTING", "-s", "192.168.0.2", "-o", "enp0s3", "-j", "MASQUERADE" ,retryable: true)
         # Run DHCP server (see patched version of https://github.com/aktowns/ikxDHCP.git)
         # pid = Process.fork
         # if pid.nil? then
         #  # In child
         #  RUN THE DHCPD function
         # else
         #  # In parent
         #  Process.detach(pid)
         # end
         # Set iptables MASQUERADE according to the ip address provided by the DHCP server to the guest
      end
        
    end
  end
end
