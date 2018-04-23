require "vagrant/util/subprocess"
require "vagrant-uml/process"

module VagrantPlugins
  module UML
    class CLI
      attr_accessor :name

      def initialize(name = nil)
        @name = name
        @logger = Log4r::Logger.new("vagrant::uml::cli")
      end

      def state(id)
        if !@name
          return :unknown
        else
          begin
            # This should be changed by a Process.new + process.run
            # to specify some options
            # Maybe use the standard Vagrant::Util::Subprocess class ... 
            if @name && Process.excute("/usr/bin/uml_mconsole" , id , "version")
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
        options = command.last.is_a?(Hash) ? command.pop : {}
        command = command.dup

        # umdir should probably be set to data_dir to prevent zombies sockets 
        process = Process.new(
          options[:data_dir] + "/run" ,
          "ubda=cow,#{options[:rootfs]}" ,
          "umid=#{options[:machine_id]}" ,
          "mem=#{options[:mem]}m" ,
          "eth0=tuntap,tap1,,192.168.1.254" ,
          "con0=null,fd:1" ,
          "con1=null,fd:2" ,
          "con=pts ssl=null" ,
          :detach => true ,
          :workdir => options[:data_dir]
        )
        process.run 
      end


    end
  end
end

        
