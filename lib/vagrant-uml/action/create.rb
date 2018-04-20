module VagrantPlugins
  module UML
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          env[:ui].info (I18n.t("vagrant_uml.copying"))
          FileUtils.cp_r(env[:machine].box.directory.to_s + "/metadata.json", env[:machine].data_dir)
          FileUtils.ln_s(env[:uml_kernel_bin], env[:machine].data_dir.to_s + "/run")
          # Generate a random id for this machine
          env[:machine].id=([*('a'..'z'),*('0'..'9')].shuffle[0,16].join.to_s)
          @app.call(env)
        end
      end
    end
  end
end
