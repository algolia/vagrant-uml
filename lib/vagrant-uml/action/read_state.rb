require "log4r"
require "vagrant-uml/cli"

module VagrantPlugins
  module UML 
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app 
          @cli    = CLI.new(env[:machine].name)
          @logger = Log4r::Logger.new("vagrant::uml::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:machine])
          @app.call(env)
        end

        def read_state(machine)
          return :not_created if machine.id.nil?
          # Return the state
          @cli.state(machine.id)
        end
      end 
    end 
  end 
end
