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

          begin
   
            @cli.run_uml( :data_dir => env[:machine].data_dir.to_s,
              :machine_name => env[:machine].name,
              :rootfs => env[:rootfs],
              :mem => 256,
              :cpu => 1,
              :eth0 => "tuntap,tap1,,192.168.1.254 con0=null,fd:2 con1=fd:0,fd:1 con=null ssl=null"
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
