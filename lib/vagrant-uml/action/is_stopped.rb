module VagrantPlugins
  module UML
    module Action
      # This can be used with "Call" built-in to check if the machine
      # is stopped and branch in the middleware.
      class IsStopped
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:result] = ( env[:machine].state.id == :stopped ||  env[:machine].state.id == :poweroff )
          @app.call(env)
        end
      end
    end
  end
end
