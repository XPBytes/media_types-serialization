# frozen_string_literal: true

require 'erb'
require 'media_types/serialization/base'

module MediaTypes
  module Serialization
    module Serializers
      class ProblemSerializer < MediaTypes::Serialization::Base

        unvalidated 'application/vnd.delftsolutions.problem'

        output do |problem, _, context|
          raise 'No translations defined, add at least one title' unless problem.translations.keys.any?

          # TODO: content-language selection
          
          translation = problem.translations[problem.translations.keys.first]
          title = translation[:title]
          detail = translation[:detail] || problem.error.message

          problem.custom_attributes.each do |key, value|
            attribute key, value
          end

          attribute :type, problem.type
          attribute :title, title unless title.nil?
          attribute :detail, detail unless detail.nil?
          attribute :instance, problem.instance unless problem.instance.nil?

          emit
        end
        output_alias 'application/problem+json'

        output_raw view: :html do |problem, _, context|
          # TODO: content-language selection
          
          translation = problem.translations[problem.translations.keys.first]
          title = translation[:title]
          detail = translation[:detail] || problem.error.message

          input = OpenStruct.new(
            title: title,
            detail: detail,
            help_url: problem.type,
            css: CommonCSS.css,
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <title>Error - <%= CGI::escapeHTML(title) %></title>
                <style>
                  <%= css.split("\n").join("\n      ") %>
                </style>
              </head>
              <body>
                <header>
                  <div id="logo"></div>
                  <h1>Error</h1>
                </header>
                <section id="content">
                  <nav>
                    <section id="description">
                      <h2><a href="<%= help_url %>"><%= CGI::escapeHTML(title) %></a></h2>
                    </section>
                  </nav>
                  <main>
                    <p><%= detail %>
                  </main>
                </section>
                <!-- Made with ❤ by: https://delftsolutions.com -->
              </body>
            </html>
          TEMPLATE
          template.result(input.instance_eval { binding })
        end

        # Hack: results in the alias being registered as */* wildcard
        self.serializer_output_registration.registrations.delete('*/*')

        output_alias_optional 'text/html', view: :html

      end
    end
  end
end
