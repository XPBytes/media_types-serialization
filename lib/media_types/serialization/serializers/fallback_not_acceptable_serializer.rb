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
          '<html lang="en"><head><title>Unable to statify acceptable media types</title></head><body>Available: ' + obj[:registrations].registrations.keys.to_s + '</body></html>'
        end
      end
    end
  end
end
