# frozen_string_literal: true

require 'delegate'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'

module MediaTypes
  module Serialization
    module Wrapper
      class RootKey < DelegateClass(String)
        def initialize(klazz)
          base = klazz.name.demodulize.chomp(MediaTypes::Serialization.common_suffix || 'Serializer').presence ||
            klazz.parent.name.demodulize
          super base.underscore
        end
      end
    end
  end
end
