# frozen_string_literal: true

require 'media_types/serialization/base'
require 'erb'
require 'cgi'

module MediaTypes
  module Serialization
    module Serializers
      class ApiViewer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        def self.viewerify(uri, current_host, type: 'last')
          viewer = URI.parse(uri)

          return uri unless viewer.host == current_host

          query_parts = viewer.query&.split('&') || []
          query_parts = query_parts.select { |p| !p.starts_with? 'api_viewer=' }
          query_parts.append("api_viewer=#{type}")
          viewer.query = query_parts.join('&')
          viewer.to_s
        end

        output_raw do |obj, version, context|
          original_identifier = obj[:identifier]
          registrations = obj[:registrations]
          original_output = obj[:output]
          original_links = obj[:links]

          api_fied_links = original_links.map do |l|
            new = l.dup
            new[:invalid] = false
            begin
              uri = viewerify(new[:href], context.request.host)
              new[:href] = uri.to_s
            rescue URI::InvalidURIError
              new[:invalid] = true
            end

            new
          end

          media_types = registrations.registrations.keys.map do |identifier|
            result = {
              identifier: identifier,
              href: viewerify(context.request.original_url, context.request.host, type: identifier),
              selected: identifier == original_identifier,
            }
            result[:href] = '#output' if identifier == original_identifier

            result
          end


          escaped_output = original_output.split("\n").
            map { |l| CGI::escapeHTML(l).gsub(/ (?= )/, '&nbsp;') }.
            map { |l| (l.gsub(/\bhttps?:\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;{}]*[-A-Z0-9+@#\/%=}~_|](?![a-z]*;)/i) do |m|
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
            end) }.
            join("<br>\n")
          

          input = OpenStruct.new(
            original_identifier: original_identifier,
            escaped_output: escaped_output,
            api_fied_links: api_fied_links,
            media_types: media_types,
            css: CommonCSS.css,
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>API Viewer [<%= CGI::escapeHTML(original_identifier) %>]</title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Api Viewer - <%= CGI::escapeHTML(original_identifier) %></h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="representations">
                      <h2>Representations:</h2>
                      <ul>
                        <% media_types.each do |m| %>
                        <li>
                          <a href="<%= m[:href] %>" <%= m[:selected] ? 'class="active" ' : '' %>>
                            <%= CGI::escapeHTML(m[:identifier]) %>
                          </a>
                        </li>
                        <% end %>
                      </ul>
                      <hr>
                    </section>
                    <section id="links">
                      <span class="label">Links:&nbsp</span>
                      <ul>
                        <% api_fied_links.each do |l| %>
                        <li><a <% if l[:invalid] %> style="color: red" <% end %>href="<%= l[:href] %>"><%= CGI::escapeHTML(l[:rel].to_s) %></a></li>
                        <% end %>
                      </ul>
                    </section>
                  </nav>
                  <main>
                    <code id="output">
                      <%= escaped_output %>
                    </code>
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
