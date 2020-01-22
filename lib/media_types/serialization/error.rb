
module MediaTypes
  module Serialization
    class Error < StandardError
    end

    class NoInputSerializerError < Error
      def initialize(msg='Unacceptable input content-type.')
        super
      end
    end
  end
end
