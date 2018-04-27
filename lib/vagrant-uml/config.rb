
module VagrantPlugins
  module UML
    class Config < Vagrant.plugin("2", :config)
      # An integer to store the pid of the UML kernel.
      #
      # @return [Integer]
      attr_reader :PID

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


      def initialize
        @PID             = UNSET_VALUE
        @create_args     = UNSET_VALUE
        @name            = UNSET_VALUE
        @mac             = UNSET_VALUE
      end


      def finalize!
        @create_args = [] if @create_args == UNSET_VALUE
        @name        = nil if @name == UNSET_VALUE
        @mac         = nil if @name == UNSET_VALUE
        @PID         = -1 if @name == UNSET_VALUE
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
