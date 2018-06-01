module VagrantPlugins
  module UML
    module Cap
      class UMLHalt
        def self.uml_halt(machine)
          begin
            machine.communicate.sudo("{ sleep 1; shutdown -h now; } >/dev/null &")
          rescue IOError, Vagrant::Errors::SSHDisconnected
            # Do nothing, because it probably means the machine shut down
            # and SSH connection was lost.
          end
        end
      end
    end
  end
end
