require "log4r"
require "ipaddr"

module VagrantPlugins
  module UML
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @env    = env
          @logger = Log4r::Logger.new("vagrant_uml::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:machine])

          @app.call(env)
        end

        def read_ssh_info(machine)
          return nil if machine.id.nil?
          # Find the ip address
          entry = @env[:machine].env.machine_index.get(env[:machine].index_uuid)
          host_ip = entry.extra_data["host_ip"]
          @env[:machine].env.machine_index.release(entry)
          guest_ip = IPAddr.new(host_ip).succ.to_s
          return { :host => guest_ip, :port => 22 }
        end

      end
    end
  end
end
