module VagrantPlugins
  module UML
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end


        def generate_mac
          format = '%02x'
          delimiter = ':'

          mac_octets = (1..3).collect { rand(256) }
          mac_octets[0] |= 0x02
          (1..3).each { mac_octets << rand(256) }
          mac = mac_octets.collect { |i| format % [i] }.join(delimiter)
        end

        def call(env)
          
          if !env[:machine].provider_config.mac
            env[:machine].provider_config.mac = generate_mac
            mac_file = env[:machine].data_dir.join("action_create"
            mac_file.open("w") do |f|
              f.write(env[:machine].provider_config.mac)
            end
          end

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
