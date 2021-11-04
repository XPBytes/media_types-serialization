# frozen_string_literal: true

require 'erb'
require 'media_types/serialization/base'
require 'media_types/serialization/utils/accept_language_header'

module MediaTypes
  module Serialization
    module Serializers
      class ProblemSerializer < MediaTypes::Serialization::Base

        unvalidated 'application/vnd.delftsolutions.problem'
        disable_wildcards

        output do |problem, _, context|
          raise 'No translations defined, add at least one title' unless problem.translations.keys.any?

          accept_language_header = Utils::AcceptLanguageHeader.new(
            context.request.get_header(HEADER_ACCEPT_LANGUAGE) || ''
          )
          translation_entry = accept_language_header.map do |locale|
            problem.translations.keys.find do |l|
              l.start_with? locale.locale
            end
          end.compact.first || problem.translations.keys.first
          translation = problem.translations[translation_entry]

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
          accept_language_header = Utils::AcceptLanguageHeader.new(
            context.request.get_header(HEADER_ACCEPT_LANGUAGE) || ''
          )
          translation_entry = accept_language_header.map do |locale|
            problem.translations.keys.find do |l|
              l.starts_with? locale.locale
            end
          end.compact.first || problem.translations.keys.first
          translation = problem.translations[translation_entry]

          title = translation[:title]
          detail = translation[:detail] || problem.error.message

          detail_lang = translation[:detail].nil? ? 'en' : translation_entry

          input = OpenStruct.new(
            title: title,
            detail: detail,
            help_url: problem.type,
            css: CommonCSS.css
          )

          template = ERB.new <<-TEMPLATE
            <html lang="en">
              <head>
                <meta content="width=device-width, initial-scale=1" name="viewport">
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
                    <section id="description" lang="#{translation_entry}">
                      <h2><a href="<%= help_url %>"><%= CGI::escapeHTML(title) %></a></h2>
                    </section>
                  </nav>
                  <main lang="#{detail_lang}">
                    <p><%= detail %>
                  </main>
                </section>
                <!-- Made with ❤ by: https://delftsolutions.com -->
              </body>
            </html>
          TEMPLATE
          template.result(input.instance_eval { binding })
        end

        enable_wildcards

        output_alias_optional 'text/html', view: :html
      end
    end
  end
end
