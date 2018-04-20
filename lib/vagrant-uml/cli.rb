require "vagrant/util/retryable"
require "vagrant/util/subprocess"
require "vagrant-uml/process"

module VagrantPlugins
  module UML
    class CLI
      include Vagrant::Util::Retryable
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
            if @name && Process.run("uml_console" , @name , "version")
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

      def run_uml(env,*command)

        Process.run( 
          env[:machine].data_dir.to_s + "/run",
          "ubda=cow,#{env[:uml_rootfs]} umid=#{env[:machine].name} mem=256m eth0=tuntap,tap1,,192.168.1.254 con0=null,fd:2 con1=fd:0,fd:1 con=null ssl=null",
          :detach => true,
          :workdir => env[:machine].data_dir.to_s
        )
      end


    end
  end
end

        
