module VagrantPlugins
  module UML
    module Action
      class CopyBox
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info (I18n.t("vagrant_uml.copying"))
          FileUtils.cp_r(Dir.glob(env[:machine].box.directory.to_s + "/*"), env[:machine].data_dir)
          @app.call(env)
        end
      end
    end
  end
end
