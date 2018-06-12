require 'pp'
require 'log4r'

module VagrantPlugins
  module UML
    module Action
      class StartInstance
         # Run a UML instance using a cow file, a tuntap ethernet adapter.

        def initialize(app, env)
          @cli = CLI.new(env[:machine].name)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t('vagrant_uml.starting'))
          env[:machine].provider.capability(:nic_mac_address)

          # The host_ip has been defined at instance creation and stored as an extra_data in its
          # global machine index.
          # Get it and use the same at each boot.
          entry = env[:machine].env.machine_index.get(env[:machine].index_uuid)
          host_ip = entry.extra_data['host_ip']
          env[:machine].env.machine_index.release(entry)

          # create the network ressource needed by the machine before starting it
          @cli.create_standalone_net(:name => env[:machine].id, :host_ip => host_ip)
          begin
            # Let's run the UML kernel with all the needed arguments
            # see http://user-mode-linux.sourceforge.net/old/switches.html
            #  for the UML kernel command line switches
            @cli.run_uml( "#{env[:machine].data_dir.to_s}/run",
              :data_dir => env[:machine].data_dir.to_s,
              :machine_id => env[:machine].id,
              :rootfs => env[:uml_rootfs],
              :mem => env[:machine].provider_config.memory,
              :ncpus => env[:machine].provider_config.cpus,
#              :eth0 => "daemon,#{env[:machine].provider_config.mac},unix,/tmp/uml_switch.ctl",
              :eth0 => "tuntap,uml-#{env[:machine].id},#{env[:machine].provider_config.mac},#{host_ip}",
              :con0 => 'null,fd:1',
              :con1 => 'null,fd:2',
              :con => 'pts',
              :ssl => 'null'
            )
            # Set the machine state to starting (it's meant to be temporary
            env[:machine_state_id] = :starting
            # Wait that UML creates the mconsole socket before continuing
            @cli.wait_for_running(env[:machine].id)
          rescue UML::Errors::ExecuteError => e
            # Execution error, we were not able to start the UML instance
            raise UML::Errors::StartError, exitcode: e.exitcode
          end
          env[:ui].success(I18n.t('vagrant_uml.started'))
          @app.call(env)
        end
      end
    end
  end
end
