begin
  require "vagrant"
rescue LoadError
  raise "The Vagrant UML plugin must be run within Vagrant."
end


module VagrantPlugins
  module UML
    class Plugin < Vagrant.plugin("2")
      name "Usermode Linux (UML) provider"
      description <<-EOF
      The UML provider allows Vagrant to manage and control
      UML-based virtual machines.
      EOF

      config(:uml, :provider) do
        require_relative "config"
        Config
      end

      # Capability that reads the mac address from the file generated at instance creation 
      provider_capability(:uml, :nic_mac_address) do
        require_relative "cap/nic_mac_address"
        Cap::NicMacAddress
      end 

      # This is a re-writen halt (shutdown) guest capability
      #  that provides a workaround for stucked Net:SSH channels 
      guest_capability(:linux, :uml_halt) do
        require_relative "cap/uml_halt"
        Cap::UMLHalt
      end

      command("uml-sudoers", primary: false) do
        require_relative "command/sudoers"
        Command::Sudoers
      end

      provider(:uml) do
        # Setup i18n
        setup_i18n

        # Return the provider
        require_relative "provider"
        Provider
      end

      # This initializes the internationalization strings.
      def self.setup_i18n
        I18n.load_path << File.expand_path("locales/en.yml", UML.source_root)
        I18n.reload!
      end

    end
  end
end
