require "pathname"

require "vagrant/action/builder"

module VagrantPlugins
  module UML
    module Action
      include Vagrant::Action::Builtin

      def self.action_up(machine)
        Vagrant::Action::Builder.new.tap do |b|
          b.use HandleBoxUrl
#          b.use ConfigValidate
          b.use CopyBox
          b.use StartInstance
        end
      end

      # This action is called to halt the machine.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
#          b.use ConfigValidate
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
#              b2.use ConfigValidate
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
#          b.use ConfigValidate
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
#          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            if !env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHRun
          end
        end
      end


      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :CopyBox, action_root.join("copy_box")
      autoload :StartInstance, action_root.join("start_instance")
      autoload :StartInstance, action_root.join("stop_instance")
      autoload :MessageAlreadyCreated, action_root.join("message_already_created")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
    end
  end
end
