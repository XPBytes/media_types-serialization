
# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      class EndpointDescriptionSerializer < MediaTypes::Serialization::Base

        unvalidated 'application/vnd.delftsolutions.endpoint_description'

        disable_wildcards

        output version: 1 do |input, version, context|
          #Rails.application.routes.recognize_path
          methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
        end

      end
    end
  end
end
