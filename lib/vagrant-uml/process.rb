require 'childprocess'
require 'log4r'

require 'vagrant/util/which'


module VagrantPlugins
  module UML
    class Process

      # Convenience method for executing a method.
      def self.execute(*command, &block)
        new(*command).execute(&block)
      end

      def initialize(*command)
        @options = command.last.is_a?(Hash) ? command.pop : {}
        @command = command.dup
        @command[0] = Which.which(@command[0]) if !File.file?(@command[0])
        if !@command[0]
          raise Errors::CommandUnavailable, file: command[0]
        end

        @logger  = Log4r::Logger.new("vagrant::util::subprocess")
      end

      def run
        execute *(['/usr/bin/env'] + @command)
      end

      # @return [TrueClass, FalseClass] subprocess is currently running
      def running?
        !!(@process && @process.alive?)
      end

      # Stop the subprocess if running
      #
      # @return [TrueClass] FalseClass] true if process was running and stopped
      def stop
        if @process && @process.alive?
          @process.stop
          true
        else
          false
        end
      end


      private
      # TODO: Review code below this line, it was pretty much a copy and
      #       paste from VirtualBox base driver and has no tests
      def execute(*command, &block)

        tries = 0
        tries = 3 if options[:retryable]

        sleep = options.fetch(:sleep, 1)

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
        if options[:show_stderr]
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

###### From vagrant Subprocess  #################
        # Get the working directory
        workdir = @options[:workdir] || Dir.pwd

        @logger.info("Starting process: #{@command.inspect}")
        @process = process = ChildProcess.build(*@command)
        process.spawn = true
        process.leader = true
        process.detach ||= @options[:detach]
        process.detach &&= false
        process.cwd = workdir
        process.detach ||= @options[:detach]
        process.io.stdout ||= @options[:stdout]
        process.io.stdout ||= Tempfile.new("out.txt")
        process.io.stderr ||= @options[:stderr]
        process.io.stderr ||= Tempfile.new("err.txt")


        Vagrant::Util::Busy.busy(int_callback) do
          process.start
        end
      end

    end
  end
end  
