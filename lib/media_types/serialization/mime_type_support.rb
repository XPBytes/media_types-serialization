# frozen_string_literal: true

require 'active_support/concern'

module MediaTypes
  module Serialization
    module MimeTypeSupport
      extend ActiveSupport::Concern

      included do
        # This is the same as doing matrr_accessor but have it isolated to the class. Subclass changes to change these
        # values, but this allows for definition as a concern.

        class << self
          attr_accessor :media_type_constructable, :serializes_html_flag, :media_type_versions
        end

        delegate :media_type_constructable, :serializes_html_flag, :media_type_versions,
                 :media_type_constructable=, :serializes_html_flag=, :media_type_versions=,
                 to: :class
      end

      class_methods do
        def current_mime_type(view: nil)
          media_type_constructable&.view(view)
        end

        def media_types(view: nil)
          media_type_view = current_mime_type(view: view)

          suffixes = [].tap do |result|
            result << :json if instance_methods.include?(:to_json)
            result << :xml if instance_methods.include?(:to_xml)
          end

          additionals = [].tap do |result|
            result << 'text/html' if serializes_html_flag || instance_methods.include?(:to_html)
          end

          [media_type_view].concat(
              media_type_versions.map { |version| media_type_view&.version(version) },
              media_type_versions.flat_map do |version|
                (suffixes).map { |suffix| media_type_view&.suffix(suffix)&.version(version) }
              end,
              additionals
          ).compact.uniq
        end

        alias_method :media_type, :media_types

        protected

        def serializes_media_type(media_type, additional_versions: [])
          self.media_type_constructable = media_type&.to_constructable
          self.media_type_versions = additional_versions
        end

        def serializes_html
          self.serializes_html_flag = true
        end
      end
    end
  end
end
