require 'media_types/serialization/version'

require 'abstract_controller'
require 'action_controller/metal/mime_responds'
require 'action_dispatch/http/mime_type'
require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'

require 'http_headers/accept'

require 'media_types/serialization/base'
require 'media_types/serialization/error'
require 'media_types/serialization/serialization_dsl'

require 'awesome_print'

require 'delegate'

class SerializationSelectorDsl < SimpleDelegator
  def initialize(controller, selected_serializer)
    @serializer = selected_serializer
    self.value = nil
    self.matched = false
    super controller
  end

  attr_accessor :value, :matched

  def serializer(klazz, obj = nil, &block)
    return if klazz != @serializer

    self.matched = true
    self.value = block.nil? ? obj : block.call
  end
end

module MediaTypes
  module Serialization

    HEADER_ACCEPT = 'HTTP_ACCEPT'

    mattr_accessor :json_encoder, :json_decoder
    if defined?(::Oj)
      self.json_encoder = Oj.method(:dump)
      self.json_decoder = Oj.method(:load)
    else
      require 'json'
      self.json_encoder = JSON.method(:pretty_generate)
      self.json_decoder = JSON.method(:parse)
    end

    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    class_methods do

      #attr_accessor :serialization_not_acceptable_serializer
      #attr_accessor :serialization_unsupported_media_type_serializer
      #attr_accessor :serialization_input_validation_failed_serializer

      def strict!(**filter_opts)
        raise "TODO: implement me"
      end

      def not_acceptable_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          @serialization_not_acceptable_serializer = serializer
        end
      end

      def unsupported_media_type_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          @serialization_unsupported_media_type_serializer ||= []
          @serialization_unsupported_media_type_serializer.append(serializer)
        end
      end

      def clear_unsupported_media_type_serializer!(**filter_opts)
        before_action(**filter_opts) do
          @serialization_unsupported_media_type_serializer = []
        end
      end

      def input_validation_failed_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          @serialization_input_validation_failed_serializer ||= []
          @serialization_input_validation_failed_serializer.append(serializer)
        end
      end

      def clear_input_validation_failed_serializers!(**filter_opts)
        before_action(**filter_opts) do
          @serialization_input_validation_failed_serializer = []
        end
      end

      ##
      # Allow output serialization using the passed in +serializer+ for the given +view+
      #
      # @see #freeze_io!
      #
      # @param serializer the serializer to use for serialization.
      # @param [(String | NilClass|)] view the view it should use the serializer for. Use nil for no view
      # @param [(String | NilClass|)[]|NilClass] views the views it should use the serializer for. Use nil for no view
      #
      def allow_output_serializer(serializer, view: nil, views: nil, **filter_opts)
        views = [view] if views.nil?

        before_action(**filter_opts) do
          @serialization_output_registrations ||= SerializationRegistration.new(:output)

          @serialization_output_registrations = @serialization_output_registrations.merge(serializer.outputs_for(views: views))
        end
      end

      ##
      # Allow input serialization using the passed in +serializer+ for the given +view+
      #
      # @see #freeze_io!
      #
      # @param serializer the serializer to use for deserialization
      # @param [(String | NilClass|)] view the view it should serializer for. Use nil for no view
      # @param [(String | NilClass|)[]|NilClass] views the views it should serializer for. Use nil for no view
      #
      def allow_input_serializer(serializer, view: [nil], **filter_opts)
        views = [view] if views.nil?

        before_action(**filter_opts) do
          @serialization_input_registrations ||= SerializationRegistration.new(:input)

          @serialization_input_registrations = @serialization_input_registrations.merge(serializer.inputs_for(views: views))
        end
      end

      ##
      # Freezes additions to the serializes and notifies the controller what it will be able to respond to.
      #
      def freeze_io!
        # TODO: check not_acceptable in before action
      end

    end
    # rubocop:enable Metrics/BlockLength

    included do
      protected

    end

    protected

    def serialize(victim, media_type, links: [])
      context = SerializationDSL.new(self, links, context: self)
      context.instance_exec { @serialization_output_registrations.call(victim, media_type, context) }
    end

    def render_media(obj: nil, serializers: nil, not_acceptable_serializer: nil, **options, &block)
      not_acceptable_serializer ||= @serialization_not_acceptable_serializer if defined? @serialization_not_acceptable_serializer

      raise "TODO: unimplemented" unless serializers.nil?
      # TODO: Convert serializers list to new registration

      @serialization_output_registrations ||= SerializationRegistration.new(:output)
      registration = @serialization_output_registrations

      identifier = resolve_media_type(request, registration)
      not_acceptable = false
      serializer = nil

      if identifier.nil?
        serializer = not_acceptable_serializer
        raise 'TODO: fall back to internal not-acceptable serializer' if serializer.nil?
        obj = request
        not_acceptable = true
      else
        serializer = resolve_serializer(request, identifier, registration)
      end

      if obj.nil? && !block.nil?
        selector = SerializationSelectorDsl.new(self, serializer)
        selector.instance_exec(&block)

        raise UnmatchedSerializerError(serializer) unless selector.matched
        obj = selector.value
      end

      links = []
      context = SerializationDSL.new(self, links, context: self)
      result = registration.call(obj, identifier, self, dsl: context)

      # TODO: Set link header
      if links.any?
        items = links.map do |l|
          href_part = "<#{l[:href]}>"
          tags = l.to_a.select { |k,_| k != :href }.map { |k,v| "#{k}=#{v}" }
          ([href_part] + tags).join('; ')
        end
        response.set_header('Link', items.join(', '))
      end

      options[:status] = :not_acceptable if not_acceptable
      render body: result, **options
      response.content_type = identifier
    end

    def deserialize(request)
      raise "TODO: unimplemented"
    end

    def deserialize!(request)
      raise "TODO: unimplemented"
    end

    def resolve_serializer(request, identifier = nil, registration = @serialization_output_registrations)
      identifier = resolve_media_type(request, registration) if identifier.nil?
      return nil if identifier.nil?

      registration = registration.registrations[identifier]
      raise 'Assertion failed, inconsistent answer from resolve_media_type' if registration.nil?
      registration.serializer
    end

    private

    def resolve_media_type(request, registration)
      # Ruby negotiation
      #
      # This is similar to the respond_to logic. It sorts the accept values and tries to match against each option.
      #
      #

      accept_header = HttpHeaders::Accept.new(request.get_header(HEADER_ACCEPT)) || ''
      accept_header.each do |mime_type|
        next unless registration.has? mime_type.to_s

        # Override Rails selected format
        request.set_header("action_dispatch.request.formats", [mime_type.to_s])
        return mime_type.to_s
      end

      nil
    end
  end
end
