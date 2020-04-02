# frozen_string_literal: true

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
        end
        output_alias 'application/problem+json'

        output_raw view: :html do |problem, _, context|
          problem.error.to_s
        end
        output_alias_optional 'text/html', view: :html

      end
    end
  end
end
