module VagrantPlugins
  module UML
    module Action
      class Create
        def initialize(app, env)
          @app = app
          @cli = CLI.new(env[:machine].name)
          @logger = Log4r::Logger.new('vagrant::uml::action::create')
        end

        # Generate a properly formatted MAC address
        #  it should have the 'locally administered' bit set
        #  and should not have the 'multicast' bit set
        def generate_mac
          format = '%02x'
          delimiter = ':'

          mac_octets = (1..6).collect { rand(256) }
          # Set the locally administered bit
          mac_octets[0] |= 0x02
          # Ensure this is not a multicast mac address by setting the LSB to 0
          mac_octets[0] -= 1 if mac_octets[0].odd?
          mac = mac_octets.collect { |i| format % [i] }.join(delimiter)
          mac.to_s
        end

        def call(env)
          data_dir = env[:machine].data_dir

          # Generate a randon and valid MAC for this instance and store it to be persistent
          env[:machine].provider_config.mac = generate_mac
          # Write this in file local to the machine
          mac_file = data_dir.join('mac_address')
          mac_file.open('w') do |f|
            f.write(env[:machine].provider_config.mac)
          end

          env[:ui].info(I18n.t('vagrant_uml.copying'))
          FileUtils.cp_r("#{env[:machine].box.directory.to_s}/metadata.json", data_dir)
          FileUtils.ln_s(env[:uml_kernel_bin], "#{data_dir.to_s}/run")

          # Generate a random id for this machine
          env[:machine].id = [*('a'..'z'), *('0'..'9')].shuffle[0, 10].join.to_s

          # Create an array to store all uml existing ip address to ease lookup
          existing_ips = []
          env[:machine].env.machine_index.each do |entry|
            if entry.provider == 'uml' && entry.id != env[:machine].index_uuid
              existing_ips << entry.extra_data['host_ip']
            end
          end
          # Check existing uml instance for ip address
	  #  and get the samllest unused octet int the network range
          smallest = 0
          # as we're using /30 subnets for tuntap, go 4 by 4
          (1..253).step(4).to_a.each do |last_oct|
            unless existing_ips.include? "10.0.113.#{last_oct}"
              smallest = last_oct
              break
            end
          end

          raise 'Network range (10.0.113.0) exhaustion' if smallest == 0
          host_ip = "10.0.113.#{smallest}"

          # Write the computed host ip address in a file
          host_ip_file = data_dir.join('host_ip_address')
          host_ip_file.open('w') do |f|
            f.write(host_ip)
          end

          # Create a cloud-init seed image
          @cli.create_cidata(root_path: env[:machine].env.root_path.to_s,
            machine_id: env[:machine].id,
            name: env[:machine].name,
            mac: env[:machine].provider_config.mac,
            data_dir: data_dir.to_s,
            host_ip: host_ip)

          # Store the host ip associated with this instance in the global machine index
          #  this is the same job as eralier writing in a file but we can't use this info
          #  in the read_ssh_info as it locks the machine and may generate issues
          #  with WaitForCommunicator
          entry = env[:machine].env.machine_index.get(env[:machine].index_uuid)
          entry.extra_data['host_ip'] = host_ip
          env[:machine].env.machine_index.set(entry)
          env[:machine].env.machine_index.release(entry)

          @app.call(env)
        end
      end
    end
  end
end
