# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/string/inflections'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaObjectWrapper < SimpleDelegator

        delegate :to_json, to: :to_hash
        delegate :class, :set, :current_view, :current_media_type, to: :__getobj__

        mattr_accessor :auto_unwrap_klazzes

        self.auto_unwrap_klazzes = [Array, defined?(ActiveRecord) ? ActiveRecord::Relation : nil].compact

        def initialize(serializer)
          __setobj__ serializer
        end

        def to_hash
          set unwrapped_serializable
          { root_key => serializable && super || nil }
        end

        alias to_h to_hash

        def header_links(view: current_view)
          __getobj__.send(:header_links, view: view)
        end

        def inspect
          "#{__getobj__.inspect} (wrapped by MediaObjectWrapper #{self.object_id})"
        end

        protected

        def unwrapped_serializable
          return __getobj__.unwrapped_serializable if __getobj__.respond_to?(:unwrapped_serializable)
          auto_unwrap_klazzes.any? { |klazz| serializable.is_a?(klazz) } ? serializable.first : serializable
        end

        def extract_links(view: current_view)
          __getobj__.send(:extract_set_links, view: view)
        end

        def root_key(view: current_view)
          __getobj__.class.root_key(view: view)
        end
      end
    end
  end
end
