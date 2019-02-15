# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/string/inflections'

require 'media_types/serialization/base'
require 'media_types/serialization/wrapper/root_key'

module MediaTypes
  module Serialization
    module Wrapper
      class MediaIndexWrapper < DelegateClass(Base)

        delegate :to_json, to: :to_hash
        delegate :class, to: :__getobj__

        def initialize(serializer)
          super serializer
        end

        def to_hash
          { Wrapper::RootKey.new(__getobj__.class).pluralize => {
            '_index': auto_wrap_serializable.map(&method(:item_hash)),
            '_links': {}
          } }
        end
        alias to_h to_hash

        def collect_links
          {}
        end

        private

        def auto_wrap_serializable
          Array(serializable)
        end

        def item_hash(item)
          __getobj__.instance_exec do
            set(item).send(:extract_self)
          end
        end
      end
    end
  end
end
