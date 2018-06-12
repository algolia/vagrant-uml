require 'vagrant/errors'

module VagrantPlugins
  module UML
    module Errors
      class ExecuteError < Vagrant::Errors::VagrantError
        error_key(:uml_execute_error)
        attr_reader :stderr, :stdout, :exitcode
        def initialize(message, *args)
          super
          return unless message.is_a?(Hash)
          @stderr = message[:stderr]
          @stdout = message[:stdout]
          @exitcode = message[:exitcode]
        end
      end

      # Raised when user interrupts a subprocess
      class SubprocessInterruptError < Vagrant::Errors::VagrantError
        error_key(:uml_interrupt_error)
        def initialize(message, *args)
          super
        end
      end

      class LinuxRequired < Vagrant::Errors::VagrantError
        error_key(:uml_linux_required)
      end

      class UmlNotInstalled < Vagrant::Errors::VagrantError
        error_key(:uml_not_installed)
      end

      class InstanceAlreadyExists < Vagrant::Errors::VagrantError
        error_key(:uml_instance_already_exists)
      end

      class CommandNotSupported < Vagrant::Errors::VagrantError
        error_key(:uml_command_not_supported)
      end

      class StartError < Vagrant::Errors::VagrantError
        error_key(:uml_start_error)
      end

      # Box related errors
      class KernelFileMissing < Vagrant::Errors::VagrantError
        error_key(:uml_kernel_missing)
      end
      class RootFSMissing < Vagrant::Errors::VagrantError
        error_key(:uml_rootfs_missing)
      end
      class IncompatibleBox < Vagrant::Errors::VagrantError
        error_key(:uml_incompatible_box)
      end
      class RedirNotInstalled < Vagrant::Errors::VagrantError
        error_key(:lxc_redir_not_installed)
      end
    end
  end
end
