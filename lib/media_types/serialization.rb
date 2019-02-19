require 'media_types/serialization/version'

require 'abstract_controller'
require 'action_controller/metal/mime_responds'
require 'action_dispatch/http/mime_type'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'

require 'http_headers/accept'

require 'media_types/serialization/no_media_type_serializers'
require 'media_types/serialization/no_serializer_for_content_type'
require 'media_types/serialization/wrapper/html_wrapper'
require 'media_types/serialization/wrapper/media_wrapper'

module MediaTypes
  module Serialization

    mattr_accessor :common_suffix, :collect_links_for_collection, :collect_links_for_index

    extend ActiveSupport::Concern

    HEADER_ACCEPT = 'HTTP_ACCEPT'
    MEDIA_TYPE_HTML = 'text/html'

    # rubocop:disable Metrics/BlockLength
    class_methods do
      # @see #freeze_accepted_media!
      #
      def accept_serialization(serializer, view: [nil], accept_html: true, **filter_opts)
        before_action(**filter_opts) do
          self.serializers = resolved_media_types(serializer, view: view) do |media_type, media_view, res|
            opts = { media_type: media_type, media_view: media_view }

            res[MEDIA_TYPE_HTML] = wrap_html(serializer, **opts) if accept_html && !res[MEDIA_TYPE_HTML]
            res[String(media_type)] = wrap_media(serializer, **opts) if media_type != MEDIA_TYPE_HTML
          end
        end
      end

      def accept_html(serializer, **filter_opts)
        before_action(**filter_opts) do
          self.serializers = resolved_media_types(serializer, view: nil) do |_, media_view, res|
            res[MEDIA_TYPE_HTML] = wrap_html(serializer, media_view: media_view, media_type: MEDIA_TYPE_HTML)
            break
          end
        end
      end

      ##
      # Register a mime type, but explicitly notify that it can't be serialized.
      # This is done for file serving and redirects.
      #
      # @param [Symbol] mimes takes a list of symbols that should resolve through Mime::Type
      #
      # @see #freeze_accepted_media!
      #
      # @example fingerpint binary format
      #
      #   no_serializer_for :fingerprint_bin, :fingerprint_deprecated_bin
      #
      def accept_without_serialization(*mimes, **filter_opts)
        before_action(**filter_opts) do
          self.serializers = Array(mimes).each_with_object(Hash(serializers)) do |mime, res|
            res[(Mime::Type.lookup_by_extension(mime) || mime).to_s] = nil
          end
        end
      end

      ##
      # Freezes additions to the serializes and notifies the controller what it will be able to respond to.
      #
      def freeze_accepted_media!
        before_action do
          # If the responders gem is available, this freezes what a controller can respond to
          if self.class.respond_to?(:respond_to)
            self.class.respond_to(*Hash(serializers).keys.map { |type| Mime::Type.lookup(type) })
          end
          serializers.freeze
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    included do
      protected

      attr_accessor :serializers
    end

    protected

    def media_type_serializer
      @media_type_serializer ||= resolve_media_type_serializer
    end

    def serialize_media(media, serializer: media_type_serializer)
      @last_serialize_media = media
      @last_media_serializer = serializer.call(media, context: self)
    end

    def media_type_json_root
      String(request.format.symbol).sub(/_json$/, '')
    end

    def respond_to_matching(matcher, &block)
      respond_to do |format|
        serializers.each_key do |mime|
          next unless matcher.call(mime: mime, format: format)
          format.custom(mime, &block)
        end
      end
    end

    def respond_to_accept(&block)
      respond_to do |format|
        serializers.each_key do |mime|
          format.custom(mime, &block)
        end

        format.any { raise_no_accept_serializer }
      end
    end

    def request_accept
      @request_accept ||= HttpHeaders::Accept.new(request.get_header(HEADER_ACCEPT) || '')
    end

    def raise_no_accept_serializer
      raise NoSerializerForContentType.new(request_accept, serializers.keys)
    end

    private

    def extract_synonym_version(synonym)
      synonym.rpartition('.').last[1..-1]
    end

    def resolve_media_type_serializer
      raise NoMediaTypeSerializers unless serializers

      # Rails negotiation
      if serializers[request.format.to_s]
        return serializers[request.format.to_s]
      end

      # Ruby negotiation
      request.accepts.each do |mime_type|
        next unless serializers.key?(mime_type.to_s)
        # Override Rails selected format
        request.set_header("action_dispatch.request.formats", [mime_type])
        return serializers[mime_type.to_s]
      end

      raise_no_accept_serializer
    end

    def resolved_media_types(serializer, view:)
      Array(view).each_with_object(Hash(serializers)) do |media_view, res|
        media_view = String(media_view)
        Array(serializer.media_type(view: media_view)).each do |media_type|
          yield media_type, media_view, res
        end
      end
    end

    def wrap_media(serializer, media_view:, media_type:)
      lambda do |*args, **opts|
        Wrapper::MediaWrapper.new(
          serializer.new(*args, media_type: media_type, view: media_view, **opts),
          view: media_view
        )
      end
    end

    def wrap_html(serializer, media_view:, media_type:)
      lambda do |*args, **opts|
        media_serializer = wrap_media(
          serializer,
          media_view: media_view,
          media_type: media_type
        ).call(*args, **opts)

        Wrapper::HtmlWrapper.new(
          media_serializer,
          view: media_view,
          mime_type: media_type.to_s,
          representations: serializers.keys,
          url_context: request.original_fullpath.chomp(".#{request.format.symbol}")
        )
      end
    end
  end
end
