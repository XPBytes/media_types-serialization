require 'media_types/serialization/error'

module MediaTypes
  module Serialization
    class NoMediaTypeSerializers < Error
      def initialize
        super 'No serializer has been set up for this request. You can not fix this by changing the request headers.'
      end
    end
  end
end
