# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/string/inflections'

require 'media_types/serialization/base'
require 'media_types/serialization/wrapper/root_key'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaCollectionWrapper < DelegateClass(Base)

        delegate :to_json, to: :to_hash
        delegate :class, to: :__getobj__

        def initialize(serializer)
          super serializer
        end

        def to_hash
          { Wrapper::RootKey.new(__getobj__.class).pluralize => {
            '_embedded': auto_wrap_serializable.map(&method(:item_hash)),
            '_links': extract_links
          } }
        end
        alias to_h to_hash

        def header_links(view: current_view)
          return __getobj__.send(:header_links, view: view) if serializable && ::MediaTypes::Serialization.collect_links_for_collection
          {}
        end

        protected

        def extract_links(view: current_view)
          return __getobj__.send(:extract_links, view: view) if serializable && ::MediaTypes::Serialization.collect_links_for_collection
          {}
        end

        private

        def auto_wrap_serializable
          Array(serializable)
        end

        def item_hash(item)
          __getobj__.instance_exec do
            set(item).send(:to_hash)
          end
        end
      end
    end
  end
end
