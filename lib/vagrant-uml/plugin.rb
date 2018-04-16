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

      provider(:uml) do
        require_relative "provider"
        Vagrant::UML::Provider
      end

      # This initializes the internationalization strings.
      def self.setup_i18n
        I18n.load_path << File.expand_path("locales/en.yml", UML.source_root)
        I18n.reload!
      end

    end
  end
end
