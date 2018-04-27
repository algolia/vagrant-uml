module VagrantPlugins
  module UML
    module Action
      class Destroy
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info I18n.t("vagrant.actions.vm.destroy.destroying")
          cow_file = env[:machine].data_dir.join('cow')
          exec_file = env[:machine].data_dir.join('run')
          if cow_file.file?
            cow_file.delete
          end
          if exec_file.file?
            exec_file = env[:machine].data_dir.join('run')
          end
          env[:machine].id = nil
          @app.call env
        end
      end
    end
  end
end
