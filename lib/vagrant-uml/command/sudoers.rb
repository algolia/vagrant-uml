require 'tempfile'


module VagrantPlugins
  module UML
    module Command
      class Sudoers < Vagrant.plugin("2", :command)

        def self.synopsis
          "Create a sudoers file to allow a non privileged users to run UML instances"
        end

        def execute
          options = { user: ENV['USER'] }

          opts = OptionParser.new do |opts|
            opts.banner = "Usage: vagrant uml sudoers"
            opts.separator ""
            opts.on('-u user', '--user user', String, "The user for which to create the policy (defaults to '#{options[:user]}')") do |u|
              options[:user] = u
            end
          end

          argv = parse_options(opts)
          return unless argv

          tunctl_path = Vagrant::Util::Which.which("tunctl")

          commands = [
            "#{tunctl_path} -u #{options[:user]} -t uml-[[\:alnum\:]]*",
            "sysctl -w net.ipv4.ip_forward=1",
            "ifconfig uml-[[\:alnum\:]]+ [[\:digit\:]\.]+/30 up",
            "iptables -t nat -A POSTROUTING -s [[\:digit\:]\.]+ -o [[\:alnum\:]-\.]+ -m comment --comment uml-[[\:alnum\:]] -j MASQUERADE",
            "iptables -t nat -L POSTROUTING --line-numbers -n",
            "iptables -t nat -D POSTROUTING [[\:digit\:]]+",
            "ip link delete uml-[[\:alnum\:]]+"
          ]
          commands.each do |cmd|
            sudoers = create_sudoers!(options[:user], cmd)
          end

          sudoers_path = "/etc/sudoers.d/vagrant-uml-#{options[:user]}"
          su_copy([
            {source: sudoers, target: sudoers_path, mode: "0440"}
          ])
        end


        private

        def create_sudoers!(user, command)
          sudoers = Tempfile.new('vagrant-uml-sudoers').tap do |file|
            file.puts "# Automatically created by vagrant-uml"
            file.puts "#{user} ALL=(root) NOPASSWD: #{command}"
          end
          sudoers.close
          sudoers.path
        end

        def su_copy(files)
          commands = files.map { |file|
            [
              "rm -f #{file[:target]}",
              "cp #{file[:source]} #{file[:target]}",
              "chown root:root #{file[:target]}",
              "chmod #{file[:mode]} #{file[:target]}"
            ]
          }.flatten
          system "echo \"#{commands.join("; ")}\" | sudo sh"
        end

      end
    end
  end
end
