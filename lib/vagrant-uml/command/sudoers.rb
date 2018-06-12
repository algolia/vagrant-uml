require 'tempfile'

module VagrantPlugins
  module UML
    module Command
      class Sudoers < Vagrant.plugin('2', :command)
        def self.synopsis
          'Create a sudoers file to allow a non privileged users to run UML instances'
        end

        def initialize(argv, env)
          super
          @argv
          @env = env
          I18n.load_path << File.expand_path('locales/en.yml', VagrantPlugins::UML.source_root)
          I18n.reload!
        end

        def execute
          options = { user: ENV['USER'] }

          opts = OptionParser.new do |opts|
            opts.banner = 'Usage: vagrant uml sudoers'
            opts.separator ''
            opts.on('-u user', '--user user', String, "The user for which to create the policy (defaults to '#{options[:user]}')") do |u|
              options[:user] = u
            end
            opts.on('-c', '--stdout', 'create an output suitable to pipe to bash or sudo bash') do |c|
              options[:stdout] = c
            end
          end

          argv = parse_options(opts)
          return unless argv

          sudoers_path = "/etc/sudoers.d/vagrant-uml-#{options[:user]}"
          create_sudoers!(options[:user], options[:stdout])
          unless options[:stdout]
            @env.ui.success(I18n.t('vagrant_uml.sudoer_file_created'))
            @env.ui.detail(I18n.t('vagrant_uml.sudoer_advise', :user => options[:user],
              :sudoer_file => File.expand_path("./vagrant-uml-#{options[:user]}")))
          end
        end

        private

        def create_sudoers!(user, to_stdout=false)
          tunctl_path = Vagrant::Util::Which.which('tunctl')
          sysctl_path = Vagrant::Util::Which.which('sysctl')
          ifconfig_path = Vagrant::Util::Which.which('ifconfig')
          iptables_path = Vagrant::Util::Which.which('iptables')
          ip_path = Vagrant::Util::Which.which('ip')

          commands = [
            "#{tunctl_path} -u #{user} -t uml-[a-zA-Z0-9]+",
            "#{sysctl_path} -w net.ipv4.ip_forward=1",
            "#{ifconfig_path} uml-[a-zA-Z0-9]+ [0-9\.]+/30 up",
            "#{iptables_path} -t nat -A POSTROUTING -s [0-9\.]+ -o [a-zA-Z0-9\-\.]+ -m comment --comment uml-[a-zA-Z0-9]+ -j MASQUERADE",
            "#{iptables_path} -t nat -L POSTROUTING --line-numbers -n",
            "#{iptables_path} -t nat -D POSTROUTING [0-9]+",
            "#{ip_path} link delete uml-[a-zA-Z0-9]+"
          ]

          template = Vagrant::Util::TemplateRenderer.new(
              'sudoers',
              :template_root  => VagrantPlugins::UML.source_root.join('templates').to_s,
              :user           => user,
              :commands       => commands
            )

          if to_stdout
            puts template.render.gsub(/^/, 'echo \'').gsub(/$/, "\' >> /etc/sudoers.d/vagrant-uml-#{user}").gsub(/^\'.*/, '')
          else
            sudoers = Tempfile.new('vagrant-uml-sudoers').tap do |file|
              file.puts template.render
            end
            sudoers.close
            FileUtils.cp(sudoers.path, "./vagrant-uml-#{user}")
          end
        end
      end
    end
  end
end
