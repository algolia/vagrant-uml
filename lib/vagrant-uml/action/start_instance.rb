require 'pp'
require "log4r"

module VagrantPlugins
  module UML
    module Action
      class StartInstance
        def initialize(app, env)
          @cli = CLI.new(env[:machine].name)
          @app = app
        end

        def call(env)
          env[:ui].info (I18n.t("vagrant_uml.starting"))
          env[:machine].provider.capability(:nic_mac_address)
          @cli.create_standalone_net(:name => env[:machine].id,:host_ip => "192.168.0.1")
          begin
            @cli.run_uml( env[:machine].data_dir.to_s + "/run",
              :data_dir => env[:machine].data_dir.to_s,
              :machine_id => env[:machine].id,
              :rootfs => env[:uml_rootfs],
              :mem => 1024,
              :ncpus => 2,
#              :eth0 => "daemon,#{env[:machine].provider_config.mac},unix,/tmp/uml_switch.ctl",
              :eth0 => "tuntap,#{env[:machine].id},#{env[:machine].provider_config.mac},192.168.0.1",
              :con0 => "null,fd:1",
              :con1 => "null,fd:2",
              :con => "pts",
              :ssl => "null"
            )
          rescue UML::Errors::ExecuteError => e
            # Execution error, we were not able to start the UML instance
            raise UML::Errors::StartError, exitcode: e.exitcode
          end
          env[:ui].success (I18n.t("vagrant_uml.started"))
          @app.call(env)
        end
      end
    end
  end
end
