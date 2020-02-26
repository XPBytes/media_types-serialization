# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      # The serializer used when no serializer has been configured.
      class FallbackNotAcceptableSerializer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        output_raw do |obj, version, context|
          #TODO: Add list of media types and correct html
          'unacceptable'
        end
      end
    end
  end
end
