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
          b.use Builtin::HandleBox
          b.use HandleBoxMetadata
          b.use Builtin::Call, IsCreated do |env, b1|
            if env[:result]
              b1.use Builtin::Call, IsStopped do |env2, b2|
                if env2[:result]
                  # Start an already created instance
                  b2.use StartInstance
                  b2.use Builtin::WaitForCommunicator, [:starting, :running]
                else
                  # Already created and running
                  b2.use MessageAlreadyCreated
                end
              end
            else
              # Instance not created
              b1.use Create
              b1.use StartInstance
              b1.use Builtin::WaitForCommunicator, [:starting, :running]
            end
          end
        end
      end

      # This action is called to halt the machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, IsCreated do |env, b2|
            if !env[:result]
               b2.use MessageNotCreated
               next
            else
              b2.use Builtin::Call, GracefulHalt, :poweroff do |env2, b3|
                if !env2[:result]
                  b3.use StopInstance
                end
                b3.use CleanInstanceNet
              end
            end
          end
        end
      end

      # This action is called to terminate the machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::DestroyConfirm do |env, b2|
            if env[:result]
              b2.use Builtin::ConfigValidate
              b2.use Builtin::Call, IsCreated do |env2, b3|
                if !env2[:result]
                  b3.use MessageNotCreated
                  next
                end

                b3.use Builtin::ProvisionerCleanup, :before if defined?(Builtin::ProvisionerCleanup)
                b3.use action_halt
                b3.use Destroy
              end
            else
              b2.use MessageWillNotDestroy
            end
          end
        end
      end

      # This action is called to read the SSH info of the machine. The
      # resulting state is expected to be put into the `:machine_ssh_info`
      # key.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use ReadSSHInfo
        end
      end


      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Builtin::SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Builtin::SSHRun
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
      autoload :IsCreated, action_root.join("is_created")
      autoload :IsStopped, action_root.join("is_stopped")
      autoload :StartInstance, action_root.join("start_instance")
      autoload :ForcedHalt, action_root.join("forced_halt")
      autoload :Destroy, action_root.join("destroy")
      autoload :HandleBoxMetadata, action_root.join("handle_box_metadata")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :ReadState, action_root.join("read_state")
      autoload :ReadSSHInfo, action_root.join("read_ssh_info")
      autoload :GracefulHalt, action_root.join("graceful_halt")
      autoload :CleanInstanceNet, action_root.join("clean_instance_net")
    end
  end
end
