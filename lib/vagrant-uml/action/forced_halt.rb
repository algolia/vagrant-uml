
module VagrantPlugins
  module UML
    module Action
      # This stops the running instance using mconsole halt (ie kill the instance).
      class ForcedHalt
        def initialize(app, env)
          @app    = app
          @cli = CLI.new(env[:machine].name)
        end

        def call(env)
          if env[:machine].state.id == :stopped || env[:machine].state.id == :not_running || env[:machine].state.id == :poweroff
            env[:ui].info (I18n.t("vagrant_uml.already_status", :status => env[:machine].state.id))
          else
            env[:ui].info (I18n.t("vagrant_uml.stopping"))
            res = Vagrant::Util::Subprocess.execute("uml_mconsole", env[:machine].id, "halt", retryable: true)
          end

          @app.call(env)
        end
      end
    end
  end
end
