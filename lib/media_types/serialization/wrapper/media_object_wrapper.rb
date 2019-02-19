# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/string/inflections'

require 'media_types/serialization/base'
require 'media_types/serialization/wrapper/root_key'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaObjectWrapper < DelegateClass(Base)

        delegate :to_json, to: :to_hash
        delegate :class, to: :__getobj__

        def initialize(serializer)
          super serializer
        end

        def to_hash
          unwrapped = auto_unwrap_serializable.tap { |u| set(u) }
          { RootKey.new(__getobj__.class).singularize => unwrapped && super || nil }
        end
        alias to_h to_hash

        def header_links(view: current_view)
          return __getobj__.send(:header_links, view: view) if serializable
          {}
        end

        private

        AUTO_UNWRAP_KLAZZES = [Array, defined?(ActiveRecord) ? ActiveRecord::Relation : nil].compact.freeze

        def auto_unwrap_serializable
          return serializable unless AUTO_UNWRAP_KLAZZES.any? { |klazz| serializable.is_a?(klazz) }
          serializable.first
        end
      end
    end
  end
end
