
module VagrantPlugins
  module UML
    module Action
      # This stops the running instance.
      class StopInstance
        def initialize(app, env)
          @app    = app
        end

        def call(env)
          if env[:machine].state.id == :stopped
            env[:ui].info(I18n.t("vagrant_uml.already_status", :status => env[:machine].state.id))
          else
            env[:ui].info(I18n.t("vagrant_uml.stopping"))
          end

          @app.call(env)
        end
      end
    end
  end
end
