module VagrantPlugins
  module UML
    module Action
      class MessageNotCreated
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_uml.not_created'))
          @app.call(env)
        end
      end
    end
  end
end
