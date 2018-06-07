module VagrantPlugins
  module UML
    module Action
      # This can be used with "Call" built-in to check if the machine
      # is created and branch in the middleware.
      class IsSudoer
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:result] = @cli.is_full_sudo_allowed
          @app.call(env)
        end
      end
    end
  end
end
