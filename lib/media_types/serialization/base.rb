# frozen_string_literal: true

require 'uri'

require 'media_types/serialization/mime_type_support'
require 'media_types/serialization/migrations_support'

require 'http_headers/link'
require 'http_headers/utils/list'

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
        entries = header_links(view: current_view).each_with_index.map do |(rel, opts), index|
          href = opts.is_a?(String) ? opts : opts.delete(:href)
          parameters =  { rel: rel }.merge(opts.is_a?(String) ? {} : opts)
          HttpHeaders::Link::Entry.new("<#{href}>", index: index, parameters: parameters)
        end
        return nil unless entries.present?

        HttpHeaders::Utils::List.to_header(entries)
      end

      COMMON_DERIVED_CALLERS = [:to_h, :to_hash, :to_json, :to_text, :to_xml, :to_html, :to_body, :extract_self].freeze

      def method_missing(symbol, *args, &block)
        if COMMON_DERIVED_CALLERS.include?(symbol)
          raise NotImplementedError, format(
            'In %<class>s, %<symbol>s is not implemented. ' \
            'Implement it or deny the MediaType[s] %<media_types>s for %<model>s',
            symbol: symbol,
            class: self.class.name,
            model: serializable.class.name,
            media_types: self.class.media_types(view: '[view]').to_s
          )
        end

        super
      end

      def respond_to_missing?(method_name, include_private = false)
        if COMMON_DERIVED_CALLERS.include?(method_name)
          return false
        end

        super
      end

      def header_links(view: current_view)
        extract_links(view: view)
      end

      protected

      attr_accessor :context, :current_media_type, :current_view

      def extract_links(view: current_view)
        {}
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
          'https://%<host>s:%<port>s%<path>s',
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
