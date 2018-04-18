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
          @logger = Log4r::Logger.new("vagrant_uml::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:machine])
          @app.call(env)
        end

        def read_state(machine)
          return :not_created if machine.id.nil?
          # Return the state
          return @cli.state
        end
      end 
    end 
  end 
end
