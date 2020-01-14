require 'media_types/serialization/version'

require 'abstract_controller'
require 'action_controller/metal/mime_responds'
require 'action_dispatch/http/mime_type'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'

require 'http_headers/accept'

require 'media_types/serialization/no_media_type_serializers'
require 'media_types/serialization/no_serializer_for_content_type'
require 'media_types/serialization/base'
require 'media_types/serialization/wrapper/html_wrapper'

require 'awesome_print'

require 'delegate'

class MediaTypeApiViewer < SimpleDelegator
  def initialize(inner_media)
    super inner_media
  end

  def to_s
    'application/vnd.xpbytes.api-viewer.v1'
  end

  def serialize_as
    __getobj__
  end
end

module MediaTypes
  module Serialization

    mattr_accessor :common_suffix, :collect_links_for_collection, :collect_links_for_index,
                   :html_wrapper_layout, :api_viewer_layout

    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    HEADER_ACCEPT         = 'HTTP_ACCEPT'

    MEDIA_TYPE_HTML       = 'text/html'
    MEDIA_TYPE_API_VIEWER = 'application/vnd.xpbytes.api-viewer.v1'

    # rubocop:disable Metrics/BlockLength
    class_methods do

      ##
      # Allow output serialization using the passed in +serializer+ for the given +view+
      #
      # By default will also accept the first call to this as HTML
      # By default will also accept the first call to this as Api Viewer
      #
      # @see #freeze_io!
      #
      # @param serializer the serializer to use for serialization. Needs to respond to #to_body, but may respond to
      #   #to_json if the type accepted is ...+json, or #to_xml if the type accepted is ...+xml or #to_html if the type
      #   accepted is text/html
      # @param [(String | NilClass|)[]] view the views it should serializer for. Use nil for no view
      # @param [Boolean] accept_api_viewer if true, accepts this serializer as base for the api viewer
      # @param [Boolean] accept_html if true, accepts this serializer as the html fallback
      #
      def allow_output_serializer(serializer, view: [nil], accept_api_viewer: true, accept_html: accept_api_viewer, **filter_opts)
        before_action(**filter_opts) do
          resolved_media_types(serializer, view: view) do |media_type, media_view, _, register|
            opts = { media_type: media_type, media_view: media_view }
            register.call(String(media_type), wrap_media(serializer, **opts))
          end
        end

        allow_output_html(serializer, view: view, overwrite: false, **filter_opts) if accept_html
        allow_output_api_viewer(serializer, view: view, overwrite: false, **filter_opts) if accept_api_viewer
      end

      def accept_serialization(serializer, view: [nil], accept_api_viewer: true, accept_html: accept_api_viewer, **filter_opts)
        STDERR.puts "accept_serialization is deprecated, please use `allow_output_serializer`. Called from #{caller(1..1).first}." if ENV['RAILS_ENV'] == 'test'
        allow_output_serializer(serializer, view: view, accept_api_viewer: accept_api_viewer, accept_html: accept_html, **filter_opts)
      end

      ##
      # Allow input serialization using the passed in +serializer+ for the given +view+
      #
      # @see #freeze_io!
      #
      # @param serializer the serializer to use for deserialization
      # @param [(String | NilClass|)[]] view the views it should serializer for. Use nil for no view
      #
      def allow_input_serializer(serializer, view: [nil], **filter_opts)
        before_action(**filter_opts) do
          self.deserializers ||= []
          view.each do |v|
            types = serializer.media_types(view: v)
            self.deserializers = self.deserializers.concat(types)
            self.input_serializer = serializer if types.include? request.content_type
          end
        end
      end

      def allow_all_input(**filter_opts)
        before_action(**filter_opts) do
          self.input_serializer = true
        end
      end

      ##
      # Allows serialization using the passed in +serializer+ for the given +view+ as text/html
      #
      # Always overwrites the current acceptor of text/html. The last call to this, for the giben +filter_opts+ will win
      # the serialization.
      #
      def allow_output_html(serializer, view: [nil], overwrite: true, **filter_opts)
        before_action(**filter_opts) do
          resolved_media_types(serializer, view: view) do |media_type, media_view, registered, register|
            break if registered.call(MEDIA_TYPE_HTML) && !overwrite
            register.call(MEDIA_TYPE_HTML, wrap_html(serializer, media_view: media_view, media_type: media_type))
          end
        end
      end

      def accept_html(serializer, view: [nil], overwrite: true, **filter_opts)
        STDERR.puts "accept_html is deprecated, please use `allow_output_html`. Called from #{caller(1..1).first}." if ENV['RAILS_ENV'] == 'test'
        allow_output_html(serializer, view: view, overwrite: overwrite, **filter_opts)
      end

      ##
      # Same as +allow_output_html+ but then for Api Viewer
      #
      def allow_output_api_viewer(serializer, view: [nil], overwrite: true, **filter_opts)
        before_action(**filter_opts) do
          fixate_content_type = (params[:api_viewer_media_type] || '').gsub(' ', '+')
          resolved_media_types(serializer, view: view) do |media_type, media_view, registered, register|
            break if registered.call(MEDIA_TYPE_API_VIEWER) && !overwrite
            if fixate_content_type == '' || fixate_content_type == media_type.to_s
              wrapped_media_type = MediaTypeApiViewer.new(fixate_content_type.presence || media_type)
              register.call(MEDIA_TYPE_API_VIEWER, wrap_html(serializer, media_view: media_view, media_type: wrapped_media_type))
              break
            end
          end
        end
      end

      def accept_api_viewer(serializer, view: [nil], overwrite: true, **filter_opts)
        STDERR.puts "accept_api_viewer is deprecated, please use `allow_output_api_viewer`. Called from #{caller(1..1).first}." if ENV['RAILS_ENV'] == 'test'
        allow_output_api_viewer(serializer, view: view, overwrite: overwrite, **filter_opts)
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
          self.serializers = Hash(serializers)
          mimes.each do |mime|
            media_type = Mime::Type.lookup_by_extension(mime) || mime
            serializers[String(media_type)] = nil
          end
        end
      end

      ##
      # Freezes additions to the serializes and notifies the controller what it will be able to respond to.
      #
      def freeze_io!
        rescue_from NoInputSerializerError, with: :unsupported_media_type

        before_action do
          # If the responders gem is available, this freezes what a controller can respond to
          if self.class.respond_to?(:respond_to)
            self.class.respond_to(*Hash(serializers).keys.map { |type| Mime::Type.lookup(type) })
          end

          self.deserializers ||= []

          serializers.freeze
          self.deserializers.freeze

          if request.body && !input_serializer
            raise NoInputSerializerError, 'This endpoint does not accept any input with this http method. Please call without a request body.' if self.deserializers.empty?
            raise NoInputSerializerError, "This endpoint does not accept #{request.content_type} with this http method. Acceptable values for the Content-Type header are: #{self.deserializers}"
          end
        end
      end

      def freeze_accepted_media!
        STDERR.puts "freeze_accepted_media! is deprecated, please use `freeze_io!`. Called from #{caller(1..1).first}." if ENV['RAILS_ENV'] == 'test'
        self.input_serializer = true # backwards compatibility.
        freeze_io!
      end
    end
    # rubocop:enable Metrics/BlockLength

    included do
      protected

      attr_accessor :serializers, :deserializers, :input_serializer

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
          result = yield mime: mime, format: format
          next unless result
          format.custom(mime) do
            result.call
          end
        end

        format.any { raise_no_accept_serializer }
      end
    end

    # def respond_to_viewer(&block)
    #  TODO: special collector that matches on api_viewer_content_type matches too
    # end

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
      #
      # The problem with rails negotiation is that it has its own logic for some of the handling that is not
      # spec compliant. If there is an exact match, that's fine and we leave it like this;
      #
      if serializers[request.format.to_s]
        return serializers[request.format.to_s]
      end

      # Ruby negotiation
      #
      # This is similar to the respond_to logic. It sorts the accept values and tries to match against each option.
      # Currently does not allow for */* or type/*.
      #
      # respond_to_accept do ... end
      #
      request.accepts.each do |mime_type|
        next unless serializers.key?(mime_type.to_s)
        # Override Rails selected format
        request.set_header("action_dispatch.request.formats", [mime_type])
        return serializers[mime_type.to_s]
      end

      raise_no_accept_serializer
    end

    def resolved_media_types(serializer, view:)
      self.serializers = Hash(serializers)

      registered = serializers.method(:key?)
      register = serializers.method(:[]=)

      Array(view).each do |media_view|
        media_view = String(media_view)
        Array(serializer.media_type(view: media_view)).each do |media_type|
          yield media_type, media_view, registered, register
        end
      end
    end

    def wrap_media(serializer, media_view:, media_type:)
      lambda do |*args, **opts|
        serializer.wrap(
          serializer.new(*args, media_type: media_type, view: media_view, **opts),
          view: media_view
        )
      end
    end

    def wrap_html(serializer, media_view:, media_type:)
      lambda do |*args, **opts|
        inner_media_type = media_type.try(:serialize_as) || media_type

        media_serializer = wrap_media(
          serializer,
          media_view: media_view,
          media_type: inner_media_type
        ).call(*args, **opts)

        override_mime_type = media_type.respond_to?(:serialize_as) ?
          "#{media_type.to_s} (#{media_type.serialize_as})" :
          media_type.to_s

        Wrapper::HtmlWrapper.new(
          media_serializer,
          view: media_view,
          mime_type: override_mime_type,
          representations: serializers.keys,
          url_context: request.original_fullpath.chomp(".#{request.format.symbol}")
        )
      end
    end
  end
end
