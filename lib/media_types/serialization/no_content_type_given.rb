require 'media_types/serialization/error'

module MediaTypes
  module Serialization
    class NoContentTypeGiven < Error
      def initialize
        super 'Unable to render data because :content_type was not passed in to "render media: data, content_type: ..."'
      end
    end
  end
end
