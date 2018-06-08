module VagrantPlugins
  module UML
    module Action
      # This action checks that the user has sufficient permission
      # to execute all privilged commands needed for the network config
      # of an UML instance.
      class IsSudoer
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:result] = @cli.is_full_sudo_allowed
          if !env[:result]
            env[:result] = @cli.is_sudo_allowed
          end
          @app.call(env)
        end
      end
    end
  end
end
