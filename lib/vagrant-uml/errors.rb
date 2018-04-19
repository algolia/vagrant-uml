require 'vagrant/errors'

module VagrantPlugins
  module UML
    module Errors
      class ExecuteError < Vagrant::Errors::VagrantError
        error_key(:execute_error)
        attr_reader :stderr, :stdout, :exitcode
        def initialize(message, *args)
          super
          if message.is_a?(Hash)
            @stderr = message[:stderr]
            @stdout = message[:stdout]
            @exitcode = message[:exitcode]
          end
        end
      end

      # Raised when user interrupts a subprocess
      class SubprocessInterruptError < Vagrant::Errors::VagrantError
        error_key(:interrupt_error)
        def initialize(message, *args)
          super
        end
      end


      class LinuxRequired < Vagrant::Errors::VagrantError
        error_key(:linux_required)
      end

      class UmlNotInstalled < Vagrant::Errors::VagrantError
        error_key(:uml_not_installed)
      end

      class ContainerAlreadyExists < Vagrant::Errors::VagrantError
        error_key(:lxc_container_already_exists)
      end

      class CommandNotSupported < Vagrant::Errors::VagrantError
        error_key(:lxc_command_not_supported)
      end

      # Box related errors
      class KernelFileMissing < Vagrant::Errors::VagrantError
        error_key(:kernel_file_missing)
      end
      class RootFSMissing < Vagrant::Errors::VagrantError
        error_key(:rootfs_missing)
      end
      class IncompatibleBox < Vagrant::Errors::VagrantError
        error_key(:incompatible_box)
      end
      class RedirNotInstalled < Vagrant::Errors::VagrantError
        error_key(:lxc_redir_not_installed)
      end
    end
  end
end
