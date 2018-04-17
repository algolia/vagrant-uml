module VagrantPlugins
  module UML
    class Config < Vagrant.plugin("2", :config)
      # An integer to store the pid of the UML kernel.
      #
      # @return [Integer]
      attr_reader :PID

      def initialize
        @PID             = UNSET_VALUE
      end
    end
  end
end
