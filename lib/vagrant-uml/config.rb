
module VagrantPlugins
  module UML
    class Config < Vagrant.plugin("2", :config)
      # Additional arguments to pass to the UML kernel when creating
      # the instance for the first time. This is an array of args.
      #
      # @return [Array<String>]
      attr_accessor :create_args

      # The name for the instance. This must be unique for all instances.
      #
      # @return [String]
      attr_accessor :name

      # The mac address of the instance. This must be unique for all instances.
      #
      # @return [String]
      attr_accessor :mac

      # The memory size (in MB) of the instance. This must be unique for all instances.
      #
      # @return [Integer]
      attr_accessor :memory


      def initialize
        @create_args     = UNSET_VALUE
        @name            = UNSET_VALUE
        @mac             = UNSET_VALUE
        @memory          = UNSET_VALUE
        @cpus            = UNSET_VALUE
      end


      def finalize!
        @create_args = [] if @create_args == UNSET_VALUE
        @name        = nil if @name == UNSET_VALUE
        @mac         = nil if @mac == UNSET_VALUE
        @memory      = nil if @memory == UNSET_VALUE
        @cpus        = nil if @cpus == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors
        if !@create_args.is_a?(Array)
          errors << I18n.t("vagrant_uml.errors.config.create_args_array")
        end
        { "uml provider" => errors }
      end

    end
  end
end
