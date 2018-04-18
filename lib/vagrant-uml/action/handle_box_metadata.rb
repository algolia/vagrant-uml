require "log4r"
module Vagrant
  module UML
    module Action
      class HandleBoxMetadata
        SUPPORTED_VERSIONS  = ['0.0.1']

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::uml::action::handle_box_metadata")
        end

        def call(env)
          @env = env
          @box = @env[:machine].box

          @env[:ui].info (I18n.t("vagrant.actions.vm.import.importing", :name => @env[:machine].box.name))

          @logger.info (I18n.t("vagrant_uml.validating_box"))
          validate_box

          @logger.info (I18n.t("vagrant_uml.setting_box"))
          @env[:uml_kernel_bin]  = kernel_bin
          @env[:uml_rootfs] = rootfs_archive

          @app.call env
        end

        def kernel_bin
          @kernel_bin ||= (box_template = @box.directory.join('linux')).to_s
        end

        def template_opts
          @template_opts ||= @box.metadata.fetch('rootfs', {}).dup.merge!(
            'rootfs'  => rootfs_archive
          )
        end

        def rootfs_archive
          @rootfs_archive ||= @box.directory.join('rootfs.gz').to_s
        end

        def validate_box
          unless SUPPORTED_VERSIONS.include? box_version
            raise Errors::IncompatibleBox.new name: @box.name,
                                              found: box_version,
                                              supported: SUPPORTED_VERSIONS.join(', ')
          end

          unless File.exists?(kernel_bin)
            raise Errors::TemplateFileMissing.new name: @box.name
          end

          unless File.exists?(rootfs_archive)
            raise Errors::RootFSTarballMissing.new name: @box.name
          end
        end

        def box_version
          @box.metadata.fetch('version')
        end
      end
    end
  end
end