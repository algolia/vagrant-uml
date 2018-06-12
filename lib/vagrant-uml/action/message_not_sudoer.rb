module VagrantPlugins
  module UML
    module Action
      class MessageNotSudoer
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ui].error(I18n.t('vagrant_uml.not_sudoer', user: ENV['USER']))
          @app.call(env)
        end
      end
    end
  end
end
