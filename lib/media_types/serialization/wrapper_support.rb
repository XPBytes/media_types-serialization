require 'active_support/concern'

require 'media_types/views'
require 'media_types/serialization/wrapper'

module MediaTypes
  module Serialization
    module WrapperSupport
      extend ActiveSupport::Concern

      AUTO_WRAPPER_MAPPING = {
        ::MediaTypes::INDEX_VIEW => ::MediaTypes::Serialization::Wrapper::MediaIndexWrapper,
        ::MediaTypes::COLLECTION_VIEW => ::MediaTypes::Serialization::Wrapper::MediaCollectionWrapper,
        ::MediaTypes::CREATE_VIEW => ::MediaTypes::Serialization::Wrapper::MediaObjectWrapper,
        nil => ::MediaTypes::Serialization::Wrapper::MediaObjectWrapper
      }.freeze

      DEFAULT_WRAPPER = ::MediaTypes::Serialization::Wrapper::MediaObjectWrapper

      class_methods do
        def wrap(serializer, view: nil)
          wrapper = AUTO_WRAPPER_MAPPING.fetch(String(view)) { DEFAULT_WRAPPER }
          wrapper.new(serializer)
        end

        def root_key(view:)
          chomped = name.demodulize.chomp(::MediaTypes::Serialization.common_suffix || 'Serializer')
          base = (chomped.presence || parent.name.demodulize).underscore
          collection_view?(view) ? base.pluralize : base.singularize
        end

        def collection_view?(view)
          view == ::MediaTypes::INDEX_VIEW || view == ::MediaTypes::COLLECTION_VIEW
        end
      end
    end
  end
end
