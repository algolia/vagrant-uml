module VagrantPlugins
  module UML
    module Action
      # This cleans instance related network ressources after (graceful)halt
      class CleanInstanceNet
        def initialize(app, env)
          @app    = app
          @cli = CLI.new(env[:machine].name)
        end

        def call(env)
          @cli.destroy_standalone_net(env[:machine].id)
          @app.call(env)
        end
      end
    end
  end
end
