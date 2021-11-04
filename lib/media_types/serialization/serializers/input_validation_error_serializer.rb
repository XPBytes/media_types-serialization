# frozen_string_literal: true

require 'media_types/serialization/base'
require 'erb'
require 'cgi'

module MediaTypes
  module Serialization
    module Serializers
      class InputValidationErrorSerializer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        def self.escape_text(text)
          text
            .split("\n")
            .map { |l| CGI.escapeHTML(l).gsub(/ (?= )/, '&nbsp;') }
            .map do |l|
              l.gsub(/\bhttps?:\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;{}]*[-A-Z0-9+@#\/%=}~_|](?![a-z]*;)/i) do |m|
                converted = m
                invalid = false
                begin
                  converted = viewerify(m, context.request.host)
                rescue URI::InvalidURIError
                  invalid = true
                end
                style = ''
                style = ' style="color: red"' if invalid
                "<a#{style} href=\"#{converted}\">#{m}</a>"
              end
            end
            .join("<br>\n")
        end

        output_raw do |obj, version, context|
          input_identifier = obj[:identifier]
          original_input = obj[:input]
          error = obj[:error]

          escaped_error = escape_text(error.message)
          escaped_input = escape_text(original_input)

          input = OpenStruct.new(
            original_identifier: input_identifier,
            escaped_error: escaped_error,
            escaped_input: escaped_input,
            css: CommonCSS.css,
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <meta content="width=device-width, initial-scale=1" name="viewport">
                <title>Invalid input detected</title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Invalid input detected</h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="representations">
                      <h2>While trying to process the <%= CGI::escapeHTML(original_identifier) %> input you sent; I encountered the following error:</h2>
                      <hr>
                    </section>
                  </nav>
                  <main>
                    <section id="error">
                      <code id="error">
                        <%= escaped_error %>
                      </code>
                    </section>
                    <section id="input">
                      <h2>Original input:</h2>
                      <code id="input">
                        <%= escaped_input %>
                      </code>
                    </section>
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
