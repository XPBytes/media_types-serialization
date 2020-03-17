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
          #TODO: Add list of media types and correct html

          #TODO: append ?api_viewer=*/* after internal links
          
          original_uri = URI.parse(context.request.original_url)
          api_fied_links = original_links.map do |l|
            new = l.dup
            new[:invalid] = false
            begin
              uri = URI.parse(new[:href])
              
              if uri.host == context.request.host
                query_parts = uri.query&.split('&') || []
                query_parts.append('api_viewer=*/*')
                uri.query = query_parts.join('&')
                new[:href] = uri.to_s
              end
            rescue URI::InvalidURIError
              new[:invalid] = true
            end

            new
          end
          
          media_types = []
          # TODO:
          # [{
          #  identfifier: 'text/html',
          #  href: 'https://...
          # }]
          escaped_output = original_output.split("\n").
            map { |l| CGI::escapeHTML(l) }.
            join("<br>\n")

          input = OpenStruct.new(
            original_identifier: original_identifier,
            original_output: escaped_output,
            api_fied_links: api_fied_links,
            media_types: media_types,
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>API Viewer [<%= CGI::escapeHTML(original_identifier) %>]</title>
              </head>
              <body>
                <h1><%= CGI::escapeHTML(original_identifier) %></h1>
                <ul>
                  <% api_fied_links.each do |l| %>
                  <li><a <% if l[:invalid] %> style="color: red" <% end %>href="<%= l[:href] %>"><%= CGI::escapeHTML(l[:rel].to_s) %></a></li>
                  <% end %>
                </ul>
                <code><pre><%= original_output %></pre></code>
                <ul>
                  <% media_types.each do |m| %>
                  <li><a href="<%= m[:href] %>"><%= CGI::escapeHTML(m[:identifier]) %></a></li>
                  <% end %>
                </ul>
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
