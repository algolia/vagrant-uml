module VagrantPlugins
  module UML
    module Action
      class Create
        def initialize(app, env)
          @app = app
          @cli = CLI.new(env[:machine].name)
          @logger = Log4r::Logger.new("vagrant::uml::action::create")
        end


        def generate_mac
          format = '%02x'
          delimiter = ':'

          mac_octets = (1..6).collect { rand(256) }
          # Set the locally administered bit
          mac_octets[0] |= 0x02
          # Ensure this is not a multicast mac address by seting the LSB to 0
          mac_octets[0] -=1 if mac_octets[0].odd?
          mac = mac_octets.collect { |i| format % [i] }.join(delimiter)
          mac.to_s
        end

        def call(env)
 
          data_dir = env[:machine].data_dir

          env[:machine].provider_config.mac = generate_mac
          mac_file = data_dir.join("action_create")
          mac_file.open("w") do |f|
            f.write(env[:machine].provider_config.mac)
          end

          env[:ui].info (I18n.t("vagrant_uml.copying"))
          FileUtils.cp_r(env[:machine].box.directory.to_s + "/metadata.json", data_dir)
          FileUtils.ln_s(env[:uml_kernel_bin], data_dir.to_s + "/run")
          # Generate a random id for this machine
          env[:machine].id=([*('a'..'z'),*('0'..'9')].shuffle[0,15].join.to_s)

          # Check existing uml instance for ip address
          host_ip = ""
          uml_inst_cpt=0
          env[:machine].env.machine_index.each do |entry|
            if entry.provider == "uml" && entry.id != env[:machine].index_uuid
              uml_inst_cpt=1
              @logger.info("Existing UML ip: #{entry.extra_data["host_ip"]}")
              (1..253).step(4).to_a.each do |last_oct|
                if "10.0.113.#{last_oct}" != entry.extra_data["host_ip"]
                  # Let's use the first free ip address in the range
                  host_ip = "10.0.113.#{last_oct}"
                  break
                end
              end
            end
          end
          raise "Network range exhaustion" if host_ip == "" && uml_inst_cpt == 1
          host_ip="10.0.113.1" if uml_inst_cpt==0

          # Create a cloud-init seed image
          @cli.create_cidata(:root_path => env[:machine].env.root_path.to_s, :machine_id => env[:machine].id, :name => env[:machine].name, :mac => env[:machine].provider_config.mac, :data_dir => data_dir.to_s, :host_ip => host_ip)

          # Store the host ip associated with this instance in the global machine index
          entry = env[:machine].env.machine_index.get(env[:machine].index_uuid)
          entry.extra_data["host_ip"] = host_ip
          env[:machine].env.machine_index.set(entry)
          env[:machine].env.machine_index.release(entry)

          @app.call(env)
        end
      end
    end
  end
end
