# frozen_string_literal: true

require 'media_types/serialization/base'
require 'erb'
require 'cgi'

module MediaTypes
  module Serialization
    module Serializers
      class ApiViewer < MediaTypes::Serialization::Base
        unvalidated 'text/html'

        output_raw do |obj, version, context|
          original_identifier = obj[:identifier]
          registrations = obj[:registrations]
          original_output = obj[:output]
          original_links = obj[:links]

          original_uri = URI.parse(context.request.original_url)
          api_fied_links = original_links.map do |l|
            new = l.dup
            new[:invalid] = false
            begin
              uri = URI.parse(new[:href])
              
              if uri.host == context.request.host
                query_parts = uri.query&.split('&') || []
                query_parts.append('api_viewer=last')
                uri.query = query_parts.join('&')
                new[:href] = uri.to_s
              end
            rescue URI::InvalidURIError
              new[:invalid] = true
            end

            new
          end
          
          stripped_original = original_uri.dup
          query_parts = stripped_original.query&.split('&') | []
          query_parts = query_parts.select { |q| !q.start_with? 'api_viewer=' }

          media_types = registrations.registrations.keys.map do |identifier|
            stripped_original.query = (query_parts + ["api_viewer=#{identifier}"]).join('&')
            result = {
              identifier: identifier,
              href: stripped_original.to_s,
              selected: identifier == original_identifier,
            }
            result[:href] = '#output' if identifier == original_identifier

            result
          end


          escaped_output = original_output.split("\n").
            map { |l| CGI::escapeHTML(l).gsub(/ (?= )/, '&nbsp;') }.
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
