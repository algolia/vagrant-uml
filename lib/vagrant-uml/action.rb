require "pathname"

require "vagrant/action/builder"

module VagrantPlugins
  module UML
    module Action
      # SHORTCUTS
      Builtin = Vagrant::Action::Builtin
      Builder = Vagrant::Action::Builder

      # This action brings the machine up from nothing, including creating the
      # container, configuring metadata, and booting.
      def self.action_up
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, Builtin::IsState, :not_created do |env, b2|
            # If the VM is NOT created yet, then do the setup steps
            b2.use Builtin::Message, I18n.t("vagrant_uml.messages.not_created")
            if env[:result]
              b2.use Builtin::HandleBox
              b2.use HandleBoxMetadata
              b2.use Create
              #b2.use Create
            end
          end
          b.use StartInstance
        end
      end

      # This action is called to halt the machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use StopInstance
          end
        end
      end

      # This action is called to terminate the machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, DestroyConfirm do |env, b2|
            if env[:result]
              b2.use Builtin::ConfigValidate
              b2.use Call, IsCreated do |env2, b3|
                if !env2[:result]
                  b3.use MessageNotCreated
                  next
                end

                b3.use ProvisionerCleanup, :before if defined?(ProvisionerCleanup)
              end
            else
              b2.use MessageWillNotDestroy
            end
          end
        end
      end


      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHRun
          end
        end
      end

      # This action is called to read the state of the machine. The
      # resulting state is expected to be put into the `:machine_state_id`
      # key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use ReadState
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :Create, action_root.join("create")
      autoload :StartInstance, action_root.join("start_instance")
      autoload :StopInstance, action_root.join("stop_instance")
      autoload :HandleBoxMetadata, action_root.join("handle_box_metadata")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :ReadState, action_root.join("read_state")
    end
  end
end
