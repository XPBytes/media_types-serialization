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
          _original_identifier = obj[:identifier]
          registrations = obj[:registrations]
          _original_output = obj[:output]
          original_links = obj[:links]
          #TODO: Add list of media types and correct html

          #TODO: append ?api_viewer=*/* after internal links
          _api_fied_links = original_links.dup
          
          _media_types = []
          # TODO:
          # [{
          #  identfifier: 'text/html',
          #  href: 'https://...
          # }]

          ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>API Viewer [<%= CGI::escapeHTML(_original_identifier) %>]</title>
              </head>
              <body>
                <h1><%= CGI::escapeHTML(_original_identifier) %></h1>
                <ul>
                  <% _api_fied_links.each do |l| %>
                  <li><a href="<%= l[:href] %>"><%= CGI::escapeHTML(l[:ref]) %></a></li>
                  <% end %>
                </ul>
                <code><pre><%= CGI::escapeHTML(_original_output) %></pre></code>
                <ul>
                  <% _media_types.each do |m| %>
                  <li><a href="<%= m[:href] %>"><%= CGI::escapeHTML(m[:identifier]) %></a></li>
                  <% end %>
                </ul>
                <!-- API viewer made with ❤ by: https://delftsolutions.com -->
              </body>
            </html>
          TEMPLATE
        end
      end
    end
  end
end
