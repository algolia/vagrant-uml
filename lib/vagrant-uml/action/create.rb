module VagrantPlugins
  module UML
    module Action
      class CopyBox
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info (I18n.t("vagrant_uml.copying"))
          FileUtils.cp_r(env[:machine].box.directory.to_s + "/metadata.json", env[:machine].data_dir)
          FileUtils.ln_s(env[:uml_kernel_bin], env[:machine].data_dir.to_s + "/run")
          @app.call(env)
        end
      end
    end
  end
end
