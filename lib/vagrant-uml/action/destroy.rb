module VagrantPlugins
  module UML
    module Action
      class Destroy
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info I18n.t('vagrant.actions.vm.destroy.destroying')

          # Delete the COW file created by the UML instance if it exists
          cow_file = env[:machine].data_dir.join('cow')
          if cow_file.file?
            cow_file.delete
          end

          exec_file = env[:machine].data_dir.join('run')
          if exec_file.file?
            exec_file = env[:machine].data_dir.join('run')
          end

          # This will trigger the vagrant data deletion by branching in the middleware
          env[:machine].id = nil
          @app.call env
        end
      end
    end
  end
end
