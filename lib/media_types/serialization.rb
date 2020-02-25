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
require 'media_types/serialization/serialization_dsl'
require 'media_types/serialization/wrapper/html_wrapper'

require 'awesome_print'

require 'delegate'

class SerializationSelectorDsl < SimpleDelegator
  def initialize(controller, selected_serializer)
    @serializer = selected_serializer
    value = nil
    matched = false
    super controller
  end

  attr_accessor :value, :matched

  def serializer(klazz, obj = nil, &block)
    return if klazz != @serializer

    matched = true
    if block.nil?
      value = obj
    else
      value = block.call
    end
  end
end

module MediaTypes
  module Serialization

    HEADER_ACCEPT         = 'HTTP_ACCEPT'

    # rubocop:disable Metrics/BlockLength
    class_methods do

      def strict!(**filter_opts)
        raise "TODO: implement me"
      end

      def not_acceptable_serializer(serializer, **filter_opts)
        raise "TODO: implement me"
      end

      def unsupported_media_type_serializer(serializer, **filter_opts)
        raise "TODO: implement me"
      end

      def clear_unsupported_media_type_serializer!(**filter_opts)
        raise "TODO: implement me"
      end

      def input_validation_failed_serializer(serializer, **filter_opts)
        raise "TODO: implement me"
      end

      def clear_input_validation_failed_serializers!(**filter_opts)
        raise "TODO: implement me"
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
          @serialization_ouput_registrations ||= SerializationRegistration.new(:output)

          @serialization_output_registrations = @serialization_output_registrations.merge(serializer.outputs_for(views))
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

          @serialization_input_registrations = @serialization_input_registrations.merge(serializer.inputs_for(views))
        end
      end

      ##
      # Freezes additions to the serializes and notifies the controller what it will be able to respond to.
      #
      def freeze_io!
      end

    end
    # rubocop:enable Metrics/BlockLength

    included do
      protected

    end

    protected

    def serialize(victim, media_type, links: [], context: nil)
      context = SerializationDSL.new(self, links, context: self)
      context.instance_eval labda { @serializer_ouput_registration.call(victim, media_type, context) }
    end

    def render_media(obj = nil, serializers: nil, not_acceptable_serializer: nil, **options, &block)
      raise "TODO: unimplemented" unless serializers.nil?
      # TODO: set not_acceptable_serializer to global one if nil?

      # TODO: Convert serializers list to new registration
      
      registration = @serializer_output_registration

      identifier = resolve_media_type(request, registration)

      serializer = resolve_serializer(request, identifier, registration)
      if serializer.nil?
        serializer = not_acceptable_serializer
        obj = request
      end

      if obj.nil? && !block.nil?
        selector = SerializationSelectorDsl.new(self, serializer)
        selector.instance_eval(&block)

        raise UnmatchedSerializerError(serializer) unless selector.matched
        obj = selector.value
      end

      links = []
      context = SerializationDSL.new(self, links, context: self)
      result = context.instance_eval labda { return registration.call(obj, identifier, self) }
      
      # TODO: Set link header
      render body: result, content_type: identifier, **options)
    end

    def deserialize(request)
      raise "TODO: unimplemented"
    end

    def deserialize!(request)
      raise "TODO: unimplemented"
    end

    def resolve_serializer(request, identifier = nil, registration = @serializer_output_registration)
      identifier = resolve_media_type(request, registration) if identifier.nil?
      return nil if identifier.nil?

      registration = registration.registrations[identifier]
      raise "Assertion failed, inconsistent answer from resolve_media_type" if registration.nil?
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
      request_accept.each do |mime_type|
        next unless @serializer_output_registration.has? mime_type

        # Override Rails selected format
        request.set_header("action_dispatch.request.formats", [mime_type])
        return mime_type
      end

      nil
    end
    end
  end
end
