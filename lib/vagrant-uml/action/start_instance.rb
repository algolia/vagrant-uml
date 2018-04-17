require 'pp'
module VagrantPlugins
  module UML
    module Action
      class StartInstance
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info (I18n.t("vagrant_uml.starting"))
          run_pid = Process.spawn(
              env[:machine].data_dir.to_s + "/run",
              :chdir => env[:machine].data_dir.to_s ,
              :out => "/vagrant/wtf.log,
              :err => '/vagrant/wtf_err.log")
          Process.detach run_pid
          env[:ui].success (I18n.t("vagrant_uml.started"))
          @app.call(env)
        end
      end
    end
  end
end
