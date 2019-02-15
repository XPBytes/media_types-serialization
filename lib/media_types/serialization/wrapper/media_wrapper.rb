# frozen_string_literal: true

require 'media_types'

require 'media_types/serialization/wrapper/media_index_wrapper'
require 'media_types/serialization/wrapper/media_collection_wrapper'
require 'media_types/serialization/wrapper/media_object_wrapper'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaWrapper

        AUTO_WRAPPER_MAPPING = {
          ::MediaTypes::INDEX_VIEW => MediaIndexWrapper,
          ::MediaTypes::COLLECTION_VIEW => MediaCollectionWrapper,
          ::MediaTypes::CREATE_VIEW => MediaObjectWrapper,
          nil => MediaObjectWrapper
        }.freeze

        DEFAULT_WRAPPER = MediaObjectWrapper

        class << self
          def new(serializer, view: nil)
            wrapper = AUTO_WRAPPER_MAPPING.fetch(String(view)) { DEFAULT_WRAPPER }
            wrapper.new(serializer)
          end
        end
      end
    end
  end
end
