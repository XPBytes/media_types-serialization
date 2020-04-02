# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      # The serializer used when no serializer has been configured.
      class FallbackNotAcceptableSerializer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        output_raw do |obj, version, context|

          available_types = []
          begin
            original_uri = URI.parse(context.request.original_url)
            stripped_original = original_uri.dup
            query_parts = stripped_original.query&.split('&') || []
            query_parts = query_parts.select { |q| !q.start_with? 'api_viewer=' }

            available_types = obj[:registrations].registrations.keys.map do |identifier|
              stripped_original.query = (query_parts + ["api_viewer=#{identifier}"]).join('&')
              {
                identifier: identifier,
                url: stripped_original.to_s,
              }
            end
          rescue URI::InvalidURIError
            available_types = obj[:registrations].registrations.keys.map do |identifier|
              {
                identifier: identifier,
                url: context.request.original_url,
              }
            end
          end

          input = OpenStruct.new(
            media_types: available_types,
            has_viewer: obj[:has_viewer],
            css: CommonCSS.css,
            acceptable_types: obj[:request].headers["Accept"] || "<none>",
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>Unable to provide requested media types</title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Not acceptable</h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="representations">
                      <h2>Please choose one of the following types:</h2>
                      <p>This endpoint tried really hard to show you the information you requested. Unfortunately you specified in your <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept">Accept header</a> that you only wanted to see the following types: <code><%= CGI::escapeHTML(acceptable_types) %></code>.
                      <p>Please add one of the following types to your Accept header to see the content or error message:
                      <hr>
                    </section>
                  </nav>
                  <main>
                    <% media_types.each do |m| %>
                    <li>
                      <a href="<%= m[:url] %>">
                        <%= CGI::escapeHTML(m[:identifier]) %>
                      </a>
                    </li>
                    <% end %>
                  </main>
                </section>
                <!-- API viewer made with ❤ by: https://delftsolutions.com -->
              </body>
            </html>
          TEMPLATE
          template.result(input.instance_eval { binding })
        end
      end
    end
  end
end
