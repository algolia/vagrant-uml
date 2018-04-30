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

          mac_octets = (1..6).collect { rand(256) }
          # Set the locally administered bit
          mac_octets[0] |= 0x02
          # Unsure this is not a multicast mac address by seting the LSB to 0
          mac_octets[0] -=1 if mac_octets[0].odd?
          mac = mac_octets.collect { |i| format % [i] }.join(delimiter)
          mac.to_s
        end

        def call(env)
          env[:machine].provider_config.mac = generate_mac
          mac_file = env[:machine].data_dir.join("action_create")
          mac_file.open("w") do |f|
            f.write(env[:machine].provider_config.mac)
          end

          env[:ui].info (I18n.t("vagrant_uml.copying"))
          FileUtils.cp_r(env[:machine].box.directory.to_s + "/metadata.json", env[:machine].data_dir)
          FileUtils.ln_s(env[:uml_kernel_bin], env[:machine].data_dir.to_s + "/run")
          # Generate a random id for this machine
          env[:machine].id=([*('a'..'z'),*('0'..'9')].shuffle[0,15].join.to_s)
          @app.call(env)
        end
      end
    end
  end
end
