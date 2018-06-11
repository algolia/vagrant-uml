require 'vagrant/ui'
require 'log4r'
require 'vagrant/util/platform'
require 'vagrant-uml/errors'

module VagrantPlugins
  module UML
    class Provider < Vagrant.plugin('2', :provider)

      def initialize(machine)

        @logger  = Log4r::Logger.new('vagrant::provider::uml')
        # Just check if we're running on a linux host
        if !Vagrant::Util::Platform.linux?
          @logger.info (I18n.t('vagrant_uml.errors.wrong_os'))
          raise UML::Errors::LinuxRequired
        end
        if !Vagrant::Util::Which.which('tunctl')
          raise Vagrant::Errors::CommandUnavailable, file: 'tunctl'
        end
        if !Vagrant::Util::Which.which('uml_switch')
          raise Vagrant::Errors::CommandUnavailable, file: 'uml_switch'
        end
        if !Vagrant::Util::Which.which('uml_mconsole')
          raise Vagrant::Errors::CommandUnavailable, file: 'uml_mconsole'
        end
        if !Vagrant::Util::Which.which('mcopy')
          raise Vagrant::Errors::CommandUnavailable, file: 'mcopy'
        end
        if !Vagrant::Util::Which.which('mkfs.vfat')
          raise Vagrant::Errors::CommandUnavailable, file: 'mkfs.vfat'
        end
        if !Vagrant::Util::Which.which('sudo')
          raise Vagrant::Errors::CommandUnavailable, file: 'sudo'
        end
        if !Vagrant::Util::Which.which('iptables')
          raise Vagrant::Errors::CommandUnavailable, file: 'iptables'
        end

        @machine = machine
      end

      def action(name)
        # Attempt to get the action method from the Action class if it
        # exists, otherwise return nil to show that we don't support the
        # given action.
        action_method = "action_#{name}"
        return Action.send(action_method) if Action.respond_to?(action_method)
        nil
      end

      def ssh_info
        return nil if state.id != :running
        env = @machine.action('read_ssh_info', lock: false)
        env[:machine_ssh_info]
      end

      def state
        env = @machine.action('read_state', lock: false)
        state_id = env[:machine_state_id]
        state_id = :unknown if !state_id

        short = state_id.to_s.gsub('_', ' ')
        long  = I18n.t("vagrant.commands.status.#{state_id}")

        # Return the MachineState object
        Vagrant::MachineState.new(state_id, short, long)
      end

      def to_s
        id = @machine.id.nil? ? 'new' : @machine.id
        "UML (#{id})"
      end 


    end
  end
end
