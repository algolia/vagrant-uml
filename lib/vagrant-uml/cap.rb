module VagrantPlugins
  module UML
    module Cap 
      # Reads the network interface card MAC addresses and returns them.
      #   
      # @return [Hash<String, String>] Adapter => MAC address
      def self.nic_mac_address(machine)
        mac_file = machine.data_dir.join("action_create")
        machine.provider_config.mac = mac_file.read.chomp if mac_file.file?
      end 

    end 
  end 
end
