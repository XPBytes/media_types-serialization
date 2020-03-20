# frozen_string_literal: true

require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      # The serializer used when no serializer has been configured.
      class FallbackUnsupportedMediaTypeSerializer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        output_raw do |obj, version, context|

          available_types = obj[:registrations].registrations.keys

          input = OpenStruct.new(
            media_types: available_types,
            css: CommonCSS.css
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>Unsupported Media Type</title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Unsupported Media Type</h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="representations">
                      <h2>Please use one of the following <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type">Content-Types</a> when making your request:</h2>
                      <hr>
                    </section>
                  </nav>
                  <main>
                    <% media_types.each do |m| %>
                    <li>
                      <%= CGI::escapeHTML(m) %>
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
