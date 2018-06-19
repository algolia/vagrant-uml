require 'log4r'
require 'ipaddr'

module VagrantPlugins
  module UML
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @env    = env
          @logger = Log4r::Logger.new('vagrant_uml::action::read_ssh_info')
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:machine])
          @app.call(env)
        end

        def read_ssh_info(machine)
          return nil if machine.id.nil?
          host_ip_file = machine.data_dir.join('host_ip_address')
          host_ip = host_ip_file.read.chomp if host_ip_file.file?
          guest_ip = IPAddr.new(host_ip).succ.to_s
          @env[:machine_ssh_info] = { host: guest_ip, port: 22 }
          @logger.debug("machine_ssh_info is: #{@env[:machine_ssh_info]}")
          return @env[:machine_ssh_info]
        end
      end
    end
  end
end
