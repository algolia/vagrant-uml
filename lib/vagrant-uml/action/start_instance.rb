require 'pp'
require "log4r"

module VagrantPlugins
  module UML
    module Action
      class StartInstance
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info (I18n.t("vagrant_uml.starting"))
          run_pid = Process.spawn(
            '/usr/bin/env',
            env[:machine].data_dir.to_s + "/run",
            "ubda=cow,#{env[:uml_rootfs]} mem=256m eth0=tuntap,tap1,,192.168.1.254 con0=null,fd:2 con1=fd:0,fd:1 con=null ssl=null",
            :chdir => env[:machine].data_dir.to_s ,
            :out => "wtf.log",
            :err => "wtf_err.log")
          Process.detach run_pid
          env[:ui].success (I18n.t("vagrant_uml.started"))
          @app.call(env)
        end
      end
    end
  end
end
