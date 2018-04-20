require "vagrant/util/retryable"
require "vagrant/util/subprocess"

module VagrantPlugins
  module UML
    class CLI
      attr_accessor :name

      def initialize(name = nil)
        @name = name
        @logger       = Log4r::Logger.new("vagrant::uml::cli")
      end

      def state
        if !@name
          return :unknown
        else
          begin
            if @name && run("uml_console" , @name , "version")
              if $1 =~ /^OK/
                @logger.debug( "Cli.state: instance is running")
                return :running
              else
                @logger.debug( "Cli.state: instance is in unknown state")
                return :unknown
              end
            end
          rescue
            ## We should try to figure out if the machine is stopped, not_created, ...
            #   test if the cow file exists ?
            @logger.debug( "Cli.state: instance is not running")
            return :not_running
          end
        end
      end

      private
      def run(*command)
        options = command.last.is_a?(Hash) ? command.last : {}
        execute *(['/usr/bin/env'] + command)
      end

      # TODO: Review code below this line, it was pretty much a copy and
      #       paste from VirtualBox base driver and has no tests
      def execute(*command, &block)
        # Get the options hash if it exists
        opts = {}
        opts = command.pop if command.last.is_a?(Hash)

        tries = 0
        tries = 3 if opts[:retryable]

        sleep = opts.fetch(:sleep, 1)

        # Variable to store our execution result
        r = nil

        retryable(:on => UML::Errors::ExecuteError, :tries => tries, :sleep => sleep) do
          # Execute the command
          r = raw(*command, &block)

################################################################################
## Need to change this as the uml_console XXXX version return 1 when the machine
## does not exists (nedd to rely on something to get the status
##  the best way would be to add a "status" command to uml_console to know is the
##  machine exists, is frozen , ...
          # If the command was a failure, then raise an exception that is
          # nicely handled by Vagrant.
          if r.exit_code != 0
            if @interrupted
              raise UML::Errors::SubprocessInterruptError, command.inspect
            else
              raise UML::Errors::ExecuteError,
                command: command.inspect, stderr: r.stderr, stdout: r.stdout, exitcode: r.exit_code
            end
          end
###################################################################################
        end

################################################################################
## We probably dont care about this as UML is only running on Linux hosts !
        # Return the output, making sure to replace any Windows-style
        # newlines with Unix-style.
        stdout = r.stdout.gsub("\r\n", "\n")
        if opts[:show_stderr]
          { :stdout => stdout, :stderr => r.stderr.gsub("\r\n", "\n") }
        else
          stdout
        end
###################################################################################
      end

      def raw(*command, &block)
        int_callback = lambda do
          @interrupted = true
          @logger.info("Interrupted.")
        end

        # Append in the options for subprocess
        command << { :notify => [:stdout, :stderr] }

        Vagrant::Util::Busy.busy(int_callback) do
          Vagrant::Util::Subprocess.execute(*command, &block)
        end
      end

    end
  end
end

        
