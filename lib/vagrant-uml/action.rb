require 'pathname'
require 'vagrant/action/builder'

module VagrantPlugins
  module UML
    module Action
      # SHORTCUTS
      Builtin = Vagrant::Action::Builtin
      Builder = Vagrant::Action::Builder

      # This action brings the machine up from nothing, including creating the
      # container, configuring metadata, and booting.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::Call, IsSudoer do |env1, b1|
            if !env1[:result]
              b1.use MessageNotSudoer
            else
              b1.use Builtin::Call, IsCreated do |env2, b2|
                b2.use Builtin::HandleBox unless env2[:result]
              end

              b1.use HandleBoxMetadata
              b1.use Builtin::ConfigValidate
              b1.use Builtin::Call, IsCreated do |env3, b3|
                if env3[:result]
                  b3.use Builtin::Call, IsStopped do |env4, b4|
                    if env4[:result]
                      # Start an already created instance
                      b4.use StartInstance
                      b4.use Builtin::WaitForCommunicator, [:starting, :running]
                      b4.use Builtin::Provision
                    else
                      # Already created and running
                      b4.use MessageAlreadyCreated
                    end
                  end
                else
                  # Instance not created
                  b3.use Create
                  b3.use StartInstance
                  b3.use Builtin::WaitForCommunicator, [:starting, :running]
                  b3.use Builtin::Provision
                end
              end
            end
          end
        end
      end

      # This action is called to halt the machine with a graceful shutdown as first step.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, IsCreated do |env, b2|
            if !env[:result]
               b2.use MessageNotCreated
               next
            else
              b2.use Builtin::Call, GracefulHalt, :poweroff, :running do |env2, b3|
                b3.use ForcedHalt unless env2[:result]
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
                unless env2[:result]
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
          b.use ReadSSHInfo
        end
      end

      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use Builtin::Call, IsStopped do |env2, b3|
              b3.use Builtin::SSHExec unless env2[:result]
            end
          end
        end
      end

      # This action is called to run a single command via SSH.
      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use Builtin::Call, IsStopped do |env2, b3|
              b3.use Builtin::SSHRun unless env2[:result]
            end
          end
        end
      end

      # This action is called when `vagrant provision` is called.
      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end
            b2.use Builtin::Provision
          end
        end
      end

      # This action is called to read the state of the machine. The
      # resulting state is expected to be put into the `:machine_state_id`
      # key.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ReadState
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :Create, action_root.join('create')
      autoload :IsCreated, action_root.join('is_created')
      autoload :IsStopped, action_root.join('is_stopped')
      autoload :StartInstance, action_root.join('start_instance')
      autoload :ForcedHalt, action_root.join('forced_halt')
      autoload :Destroy, action_root.join('destroy')
      autoload :HandleBoxMetadata, action_root.join('handle_box_metadata')
      autoload :MessageAlreadyCreated, action_root.join('message_already_created')
      autoload :MessageNotCreated, action_root.join('message_not_created')
      autoload :MessageWillNotDestroy, action_root.join('message_will_not_destroy')
      autoload :ReadState, action_root.join('read_state')
      autoload :ReadSSHInfo, action_root.join('read_ssh_info')
      autoload :GracefulHalt, action_root.join('graceful_halt')
      autoload :CleanInstanceNet, action_root.join('clean_instance_net')
      autoload :IsSudoer, action_root.join('is_sudoer')
      autoload :MessageNotSudoer, action_root.join('message_not_sudoer')
    end
  end
end
