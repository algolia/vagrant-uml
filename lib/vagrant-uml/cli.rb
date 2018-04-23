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
            res = Vagrant::Util::Subprocess.execute("uml_mconsole", id, "version", retryable: true)
            if res.stdout =~ /^OK/
              @logger.debug( "Cli.state: instance is running")
              return :running
            else
              return :not_running
            end
          rescue
            ## We should try to figure out if the machine is stopped, not_created, ...
            #   test if the cow file exists ?
            @logger.debug( "Cli.state: RESCUE instance state unknown error during call to uml_mconsole")
            return :unknow
          end
        end
      end

      def run_uml(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}
        command = command.dup

        res = Vagrant::Util::Subprocess.execute("tunctl", "-t", options[:machine_id], retryable: true)
        res2 = Vagrant::Util::Subprocess.execute("ifconfig", options[:machine_id], "192.168.1.254" , "up", retryable: true)

        # umdir should probably be set to data_dir to prevent zombies sockets 
        process = Process.new(
          command[0],
          "ubda=cow,#{options[:rootfs]}" ,
          "umid=#{options[:machine_id]}" ,
          "mem=#{options[:mem]}m" ,
          "eth0=tuntap,#{options[:machine_id]},,192.168.1.254" ,
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

        
