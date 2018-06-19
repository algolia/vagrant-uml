module VagrantPlugins
  module UML
    module Action
      class MessageAlreadyCreated
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_uml.already_status', status: 'created'))
          @app.call(env)
        end
      end
    end
  end
end
