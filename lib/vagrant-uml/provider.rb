require "vagrant/ui"
require "log4r"
require 'vagrant/util/platform'

module VagrantPlugins
  module UML
    class Provider < Vagrant.plugin("2", :provider)
      def initialize(machine)
        @logger  = Log4r::Logger.new("vagrant::provider::uml")
        if !Vagrant::Util::Platform.linux?
          @logger.info (I18n.t("vagrant_uml.errors.wrong_os"))
          raise Vagrant::Errors::ProviderNotUsable,
            machine: machine.name,
            provider: 'uml',
            message: I18n.t("vagrant_uml.errors.wrong_os")
        end

        @machine = machine
      end

      def action(name)
        action_method = "action_#{name}"
        return Action.send(action_method, @machine) if Action.respond_to?(action_method)
        nil
      end

      def ssh_info
        nil
      end

      def machine_id_changed
        nil
      end

      def state
        nil
      end
    end
  end
end
