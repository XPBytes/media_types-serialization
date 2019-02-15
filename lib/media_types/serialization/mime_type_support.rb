# frozen_string_literal: true

require 'active_support/concern'

module MediaTypes
  module Serialization
    module MimeTypeSupport
      extend ActiveSupport::Concern

      class_methods do
        def current_mime_type(view: nil)
          media_type_&.to_constructable&.view(view)
        end

        def media_types(view: nil)
          media_type_view = current_mime_type(view: view)
          [media_type_view].concat(
            media_type_versions_.map { |version| media_type_view&.version(version) },
            serializes_html_ ? ['text/html'] : []
          ).compact
        end

        alias_method :media_type, :media_types

        protected

        def serializes_media_type(media_type, additional_versions: [])
          self.media_type_ = media_type
          self.media_type_versions_ = additional_versions
        end

        def serializes_html
          self.serializes_html_ = true
        end

        private

        attr_accessor :media_type_, :serializes_html_, :media_type_versions_
      end
    end
  end
end
