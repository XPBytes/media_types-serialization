
# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      class EndpointDescriptionSerializer < MediaTypes::Serialization::Base

        unvalidated 'application/vnd.delftsolutions.endpoint_description'

        disable_wildcards

        output version: 1 do |input, version, context|
          request_path = context.request.original_fullpath.split('?')[0]

          path_prefix = ENV.fetch('RAILS_RELATIVE_URL_ROOT') { '' }
          request_path = request_path.sub(path_prefix, '')

          my_controller = Rails.application.routes.recognize_path request_path

          methods_available = {}
          methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
          methods.each do |m|
            begin
              found_controller = Rails.application.routes.recognize_path request_path, method: m
              if found_controller[:controller] == my_controller[:controller]
                methods_available[m] = found_controller[:action]
              end
            rescue ActionController::RoutingError
              # not available
            end
          end

          {
            methods: methods_available,
            input: input,
          }

        end

      end
    end
  end
end
