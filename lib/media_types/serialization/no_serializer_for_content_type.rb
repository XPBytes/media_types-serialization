require 'media_types/serialization/error'

module MediaTypes
  module Serialization
    class NoSerializerForContentType < Error
      def initialize(given, supported)
        super format(
          'Unable to serialize to requested Content-Type: %<given>s. I can give you: %<supported>s',
          given: Array(given).map(&:to_s).inspect,
          supported: supported.map(&:to_s)
        )
      end
    end
  end
end
