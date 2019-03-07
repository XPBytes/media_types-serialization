# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/string/inflections'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaIndexWrapper < SimpleDelegator

        delegate :to_json, to: :to_hash
        delegate :class, :set, :current_view, :current_media_type, to: :__getobj__

        def initialize(serializer)
          __setobj__ serializer
        end

        def to_hash
          {
            root_key => {
              '_index': wrapped_serializable.map(&method(:item_hash)),
              '_links': extract_links
            }
          }
        end
        alias to_h to_hash

        def header_links(view: current_view)
          return __getobj__.send(:header_links, view: view) if ::MediaTypes::Serialization.collect_links_for_index
          {}
        end

        protected

        def wrapped_serializable
          return __getobj__.wrapped_serializable if __getobj__.respond_to?(:wrapped_serializable)
          return [serializable] if serializable.is_a?(::Hash)
          Array(serializable)
        end

        def item_hash(item)
          __getobj__.instance_exec do
            set(item).send(:extract_self)
          end
        end

        def extract_links(view: current_view)
          return __getobj__.send(:extract_links, view: view) if ::MediaTypes::Serialization.collect_links_for_index
          {}
        end

        def root_key(view: current_view)
          __getobj__.class.root_key(view: view)
        end
      end
    end
  end
end
