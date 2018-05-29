require "log4r"
module VagrantPlugins
  module UML
    module Action
      class HandleBoxMetadata
        SUPPORTED_VERSIONS  = ['0.0.1','0.0.2']

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
          begin
            if (kernel_ver = @box.metadata.fetch('kernel_version').to_s)
              @kernel_bin ||= (box_template = @box.directory.join('linux-'+kernel_ver)).to_s
            end
            rescue
          end
          @kernel_bin ||= (box_template = @box.directory.join('linux')).to_s
        end

        def template_opts
          @template_opts ||= @box.metadata.fetch('rootfs', {}).dup.merge!(
            'rootfs'  => rootfs_archive
          )
        end

        def rootfs_archive
          begin
            rootfs_file ||= @box.metadata.fetch('rootfs').to_s
            rescue
          end
          rootfs_file ||= 'rootfs'
          @rootfs_archive ||= @box.directory.join(rootfs_file).to_s
        end

        def validate_box
          unless SUPPORTED_VERSIONS.include? box_version
            raise UML::Errors::IncompatibleBox.new name: @box.name,
                                              found: box_version,
                                              supported: SUPPORTED_VERSIONS.join(', ')
          end

          unless File.exists?(kernel_bin)
            raise UML::Errors::KernelFileMissing.new name: @box.name,
                                                 kernel: kernel_bin
          end

          unless File.exists?(rootfs_archive)
            raise UML::Errors::RootFSMissing.new name: @box.name,
                                                  rootfs: rootfs_archive
          end
        end

        def box_version
          @box.metadata.fetch('version')
        end
      end
    end
  end
end
