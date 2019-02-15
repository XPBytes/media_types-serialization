# frozen_string_literal: true

require 'uri'

require 'media_types/serialization/mime_type_support'
require 'media_types/serialization/migrations_support'

module MediaTypes
  module Serialization
    class Base
      include MimeTypeSupport
      include MigrationsSupport

      attr_accessor :serializable

      def initialize(serializable, media_type:, view: nil, context:)
        self.context = context
        self.current_media_type = media_type
        self.current_view = view

        set(serializable)
      end

      def to_link_header
        {}
      end

      def to_hash
        raise NotImplementedError, format(
          'In %<class>s, to_hash is not implemented.',
          class: self.class.name
        )
      end

      def to_h
        raise NotImplementedError, format(
          'In %<class>s, to_h is not implemented. Missing alias to_h to_hash.',
          class: self.class.name
        )
      end

      protected

      attr_accessor :context, :current_media_type, :current_view

      def extract_self
        raise NotImplementedError, format(
          'In %<class>s, extract_self is not implemented, thus a self link for %<model>s can not be generated. Implement ' \
          'extract_self on %<class>s or deny the MediaType[s] %<media_types>s for this request.',
          class: self.class.name,
          model: serializable.class.name,
          media_types: self.class.media_types(view: '[view]').to_s
        )
      end

      def extract_links
        {}
      end

      def header_links
        extract_links
      end

      def set(serializable)
        self.serializable = serializable
        self
      end

      def extract(extractable, *keys)
        return {} unless keys.present?
        extractable.slice(*keys)
      rescue TypeError => err
        raise TypeError, format(
          '[serializer] failed to slice keys to extract. Given keys: %<keys>s. Extractable: %<extractable>s' \
          'Error: %<error>s',
          keys: keys,
          extractable: extractable,
          error: err
        )
      end

      def resolve_file_url(url)
        return url if !url || URI(url).absolute?

        format(
          'http://%<host>s:%<port>s%<path>s',
          host: context.default_url_options[:host],
          port: context.default_url_options[:port],
          path: url
        )
      rescue URI::InvalidURIError
        url
      end
    end
  end
end
