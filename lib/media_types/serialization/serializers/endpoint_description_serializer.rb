
# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      class EndpointDescriptionSerializer < MediaTypes::Serialization::Base

        unvalidated 'application/vnd.delftsolutions.endpoint_description'

        disable_wildcards

        def self.to_input_identifiers(serializers)
          serializers.flat_map do |s|
            s[:serializer].inputs_for(views: [s[:view]]).registrations.keys
          end
        end
        def self.to_output_identifiers(serializers)
          serializers.flat_map do |s|
            s[:serializer].outputs_for(views: [s[:view]]).registrations.keys
          end
        end

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

          input_definitions = input[:actions][:input] || {}
          output_definitions = input[:actions][:output] || {}
          viewer_definitions = input[:api_viewer] || {}

          result = {}
          global_in = input_definitions['all_actions'] || []
          global_out = output_definitions['all_actions'] || []
          global_viewer = viewer_definitions['all_actions'] || false

          viewer_uri = URI.parse(context.request.original_url)
          query_parts = viewer_uri.query&.split('&') || []
          query_parts = query_parts.select { |q| !q.start_with? 'api_viewer=' }
          viewer_uri.query = (query_parts + ["api_viewer=last"]).join('&')

          methods_available.each do |method, action|
            has_viewer = viewer_definitions[action] || global_viewer
            input_serializers = global_in + (input_definitions[action] || [])
            output_serializers = global_out + (output_definitions[action] || [])
            result[method] = {
              input: to_input_identifiers(input_serializers),
              output: to_output_identifiers(output_serializers),
            }

            result[method].delete(:input) if method == 'GET'
            result[method][:api_viewer] = viewer_uri.to_s if has_viewer
          end

          result
        end

      end
    end
  end
end
