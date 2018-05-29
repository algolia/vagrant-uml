require "vagrant/util/subprocess"
require "vagrant-uml/process"
require "tmpdir"
require "fileutils"
require "ipaddr"

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
              @logger.debug( "instance is running")
              return :running
            else
              return :poweroff
            end
          rescue
            ## We should try to figure out if the machine is stopped, not_created, ...
            #   test if the cow file exists ?
            @logger.debug( "instance state unknown error during call to uml_mconsole")
            return :unknown
          end
        end
      end

      def create_cidata(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}

        @logger.debug( "root_path = #{options[:root_path]}")
        # We may use guestfs bindings, but ruby-guests requires a lot of dependencies ...
        mkfs = Vagrant::Util::Which.which("mkfs.vfat")
        mcopy = Vagrant::Util::Which.which("mcopy")

        guest_ip = IPAddr.new("#{options[:host_ip]}/30").succ.to_s

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
        address: #{guest_ip}
        netmask: 255.255.255.252
        gateway: #{options[:host_ip]}
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
          mtools_env = []
          mtools_env << ["MTOOLS_SKIP_CHECK", "1"]
          Vagrant::Util::Subprocess.execute(mcopy,"-oi", "#{dir}/cloud-init.vfat", "#{dir}/meta-data", "#{dir}/user-data", "#{dir}/network-config","::", retryable: true, :env => mtools_env)
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
         res = Vagrant::Util::Subprocess.execute("ip", "-4", "route", "list", "match", "0.0.0.0", retryable: true)
         res.stdout =~ /default via ([0-9.]+) dev (\S+)(\s+\S+)*/
         default_interface = $2.to_s
         Vagrant::Util::Subprocess.execute("ifconfig", options[:name], options[:host_ip]+"/30", "up", retryable: true)
         Vagrant::Util::Subprocess.execute("sysctl", "-w", "net.ipv4.ip_forward=1", retryable: true)
         Vagrant::Util::Subprocess.execute("iptables", "-t", "nat", "-A" , "POSTROUTING", "-s", "192.168.0.2", "-o", default_interface, "-m", "comment", "--comment", options[:name], "-j", "MASQUERADE" ,retryable: true)
      end

      def destroy_standalone_net(id)
        res = Vagrant::Util::Subprocess.execute("iptables", "-t", "nat", "-L", "POSTROUTING", "--line-numbers", "-n", retryable: true)
        res.stdout =~ /([0-9]+)\s+MASQUERADE\s+all\s+--\s+[0-9.]+\s+0\.0\.0\.0\/0\s+\/\*\s+#{id}\s+\*\//
        rule_number = $1.to_s
        Vagrant::Util::Subprocess.execute("iptables", "-t", "nat", "-D", "POSTROUTING", rule_number, retryable: true) if rule_number && rule_number.length > 0
        Vagrant::Util::Subprocess.execute("ip", "link", "delete", id, retryable: true)
      end
        
    end
  end
end
