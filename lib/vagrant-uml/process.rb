require 'childprocess'
require 'log4r'
require 'tempfile'
require 'vagrant/util/retryable'
require 'vagrant/util/which'

module VagrantPlugins
  module UML
    class Process
      include Vagrant::Util::Retryable

      # Convenience method for executing a method.
      def self.execute(*command, &block)
        new(*command).execute(&block)
      end

      def initialize(*command)
        @logger  = Log4r::Logger.new('vagrant::uml::process')
        @options = command.last.is_a?(Hash) ? command.pop : {}
        @command = command.dup
        @logger.debug("Starting process with command: #{@command.inspect}")
        @command[0] = Which.which(@command[0]) unless File.file?(@command[0])
        raise Errors::CommandUnavailable, file: command[0] unless @command[0]
        @command.join(' ')
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
        tries = 3 if @options[:retryable]
        # Ensure detachable process are ,not retryable
        tries = 0 if @options[:detach]

        sleep = @options.fetch(:sleep, 1)

        # Variable to store our execution result
        r = nil

        retryable(:on => UML::Errors::ExecuteError, :tries => tries, :sleep => sleep) do
          # Execute the command
          r = raw(*command, &block)

          ################################################################################
          ## Need to change this as the uml_console XXXX version return 1 when the machine
          ## does not exists (need to rely on something to get the status)
          ##  the best way would be to add a "status" command to uml_console to know is the
          ##  machine exists, is frozen , ...
          # If the command was a failure, then raise an exception that is
          # nicely handled by Vagrant.
          if r.exit_code != 0 && r.exited? && !@options[:detach]
            if @interrupted
              raise UML::Errors::SubprocessInterruptError, command.inspect
            else
              raise UML::Errors::ExecuteError,
                command: command.inspect, stderr: r.io.stderr, stdout: r.io.stdout, exitcode: r.exit_code
            end
          end
          ###################################################################################
        end

        ################################################################################
        ## We probably dont care about this as UML is only running on Linux hosts !
        # Return the output, making sure to replace any Windows-style
        # newlines with Unix-style.
        #        stdout = r.stdout.gsub("\r\n", "\n")
        #        if options[:show_stderr]
        #          { :stdout => stdout, :stderr => r.stderr.gsub("\r\n", "\n") }
        #        else
        #          stdout
        #        end
        ###################################################################################
        return r
      end

      def raw(*command, &block)
        int_callback = lambda do
          @interrupted = true
          @logger.info('Interrupted.')
        end

###### From vagrant Subprocess  #################
        # Get the working directory
        workdir = @options[:workdir] || Dir.pwd
        @process = process = ChildProcess.build(*@command)
        process.leader = true
        process.detach = false
        process.duplex = true
        process.detach ||= @options[:detach]
        process.cwd = workdir
        #process.io.stdout ||= @options[:stdout]
        process.io.stdout ||= File.new('out.txt', File::CREAT|File::TRUNC|File::RDWR, 0640)
        #process.io.stderr ||= @options[:stderr]
        process.io.stderr ||= File.new('err.txt', File::CREAT|File::TRUNC|File::RDWR, 0640)

        Vagrant::Util::Busy.busy(int_callback) do
          @logger.debug("Starting process: #{@command.inspect}")
          process.start
          process.io.stdin.close
        end
        return process
      end
    end
  end
end
