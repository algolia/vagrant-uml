
module VagrantPlugins
  module UML
    module Action
      # This stops the running instance.
      class StopInstance
        def initialize(app, env)
          @app    = app
        end

        def call(env)
          if env[:machine].state.id == :stopped || env[:machine].state.id == :not_running
            env[:ui].info (I18n.t("vagrant_uml.already_status", :status => env[:machine].state.id))
          else
            env[:ui].info (I18n.t("vagrant_uml.stopping"))
            # We should kill the instance either with uml_mconsole, sending shutdown to ssh , by killing the pid ?
            res = Vagrant::Util::Subprocess.execute("uml_mconsole", env[:machine].id, "halt", retryable: true)
          end

          @app.call(env)
        end
      end
    end
  end
end
