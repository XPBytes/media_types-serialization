require 'media_types/serialization/version'
require 'media_types/serialization/serializers/fallback_not_acceptable_serializer'
require 'media_types/serialization/serializers/api_viewer'

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
      self.json_encoder = ->(obj) { Oj.dump(obj, {indent: 2, space: ' '} ) }
      self.json_decoder = Oj.method(:load)
    else
      require 'json'
      self.json_encoder = JSON.method(:pretty_generate)
      self.json_decoder = JSON.method(:parse)
    end

    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    class_methods do

      def not_acceptable_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_not_acceptable_serializer = serializer
        end
      end

      def unsupported_media_type_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_unsupported_media_type_serializer ||= []
          @serialization_unsupported_media_type_serializer.append(serializer)
        end
      end

      def clear_unsupported_media_type_serializer!(**filter_opts)
        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_unsupported_media_type_serializer = []
        end
      end

      def input_validation_failed_serializer(serializer, **filter_opts)
        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_input_validation_failed_serializer ||= []
          @serialization_input_validation_failed_serializer.append(serializer)
        end
      end

      def clear_input_validation_failed_serializers!(**filter_opts)
        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

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
        raise SerializersAlreadyFrozenError if defined? @serialization_frozen
        raise ArrayInViewParameterError, :allow_output_serializer if view.is_a? Array

        views = [view] if views.nil?

        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_output_registrations ||= SerializationRegistration.new(:output)

          @serialization_output_registrations = @serialization_output_registrations.merge(serializer.outputs_for(views: views))
        end
      end
      
      def allow_api_viewer(serializer: MediaTypes::Serialization::Serializers::ApiViewer, **filter_opts)
        before_action(**filter_opts) do
          return unless request.query_parameters['api_viewer']

          @serialization_override_accept = request.query_parameters['api_viewer']
          @serialization_wrapping_renderer = serializer
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
      def allow_input_serializer(serializer, view: nil, views: nil, **filter_opts)
        raise ArrayInViewParameterError, :allow_input_serializer if view.is_a? Array
        views = [view] if views.nil?

        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_input_registrations ||= SerializationRegistration.new(:input)

          @serialization_input_registrations = @serialization_input_registrations.merge(serializer.inputs_for(views: views))
        end
      end

      def allow_all_input(**filter_opts)
        before_action(**filter_opts) do
          @serialization_input_allow_all ||= true
        end
      end

      ##
      # Freezes additions to the serializes and notifies the controller what it will be able to respond to.
      #
      def freeze_io!
        before_action do
          raise UnableToRefreezeError if defined? @serialization_frozen

          @serialization_frozen = true
          @serialization_input_registrations ||= SerializationRegistration.new(:input)

          raise NoOutputSerializersDefinedError unless defined? @serialization_output_registrations

          all_allowed = false
          all_allowed ||= @serialization_input_allow_all if defined?(@serialization_input_allow_all)

          input_is_allowed = true
          unless request.content_type.blank?
            input_is_allowed = @serialization_input_registrations.has? request.content_type
            begin
              @serialization_decoded_input = @serialization_input_registrations.decode(request.body, request.content_type, self)
            rescue InputValidationFailedError => e
              raise 'TODO: render with validation failed serializer'
            end
          end

          unless input_is_allowed or all_allowed
            raise 'TODO: render with unacceptable input serializer'
          end

          resolved_identifier = resolve_media_type(request, @serialization_output_registrations)

          not_acceptable_serializer = nil
          not_acceptable_serializer = @serialization_not_acceptable_serializer if defined? @serialization_not_acceptable_serializer
          not_acceptable_serializer ||= MediaTypes::Serialization::Serializers::FallbackNotAcceptableSerializer

          serialization_render_not_acceptable(@serialization_output_registrations, not_acceptable_serializer) if resolved_identifier.nil?
        end
      end

    end
    # rubocop:enable Metrics/BlockLength

    included do
      protected

    end

    protected

    def serialize(victim, media_type, serializer: Object.new, links: [])
      context = SerializationDSL.new(serializer, links, context: self)
      context.instance_exec { @serialization_output_registrations.call(victim, media_type, context) }
    end

    def render_media(obj: nil, serializers: nil, not_acceptable_serializer: nil, **options, &block)
      raise SerializersNotFrozenError unless defined? @serialization_frozen

      not_acceptable_serializer ||= @serialization_not_acceptable_serializer if defined? @serialization_not_acceptable_serializer


      @serialization_output_registrations ||= SerializationRegistration.new(:output)
      registration = @serialization_output_registrations
      unless serializers.nil?
        registration = SerializationRegistration.new(:output)
        serializers.each do |s|
          registration = registration.merge(s.registrations)
        end
      end

      identifier = resolve_media_type(request, registration)

      if identifier.nil?
        serialization_render_not_acceptable(registration, not_acceptable_serializer)
        return
      end

      serializer = resolve_serializer(request, identifier, registration)

      if obj.nil? && !block.nil?
        selector = SerializationSelectorDsl.new(self, serializer)
        selector.instance_exec(&block)

        raise UnmatchedSerializerError(serializer) unless selector.matched
        obj = selector.value
      end

      serialization_render_resolved(obj: obj, serializer: serializer, identifier: identifier, registrations: registration, options: options)
    end

    def deserialize(request)
      raise SerializersNotFrozenError unless defined?(@serialization_frozen)

      result = nil
      begin
        result = deserialize!(request)
      rescue NoInputReceivedError
        return nil
      end
      result
    end

    def deserialize!(request)
      raise SerializersNotFrozenError unless defined?(@serialization_frozen)
      raise NoInputReceivedError unless request.content_type
      raise InputNotAcceptableError unless @serialization_input_registrations.has_key? request.content_type
      @serialization_input_registrations.call(@serialization_decoded_input, request.content_type, self)
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
      return @serialization_override_accept if defined? @serialization_override_accept

      # Ruby negotiation
      #
      # This is similar to the respond_to logic. It sorts the accept values and tries to match against each option.
      #
      #

      accept_header = HttpHeaders::Accept.new(request.get_header(HEADER_ACCEPT)) || ''
      accept_header.each do |mime_type|
        next unless registration.has? mime_type.to_s

        return mime_type.to_s
      end

      nil
    end

    def serialization_render_not_acceptable(registrations, override = nil)
        serializer = override
        serializer ||= MediaTypes::Serialization::Serializers::FallbackNotAcceptableSerializer
        identifier = serializer.validator.identifier
        obj = { request: request, registrations: registrations }
        new_registrations = serializer.outputs_for(views: [nil])
      
        serialization_render_resolved(obj: obj, serializer: serializer, identifier: identifier, registrations: new_registrations, options: {})
        response.status = :not_acceptable
    end

    def serialization_render_resolved(obj:, identifier:, serializer:, registrations:, options:)
      links = []
      context = SerializationDSL.new(serializer, links, context: self)
      result = registrations.call(obj, identifier, self, dsl: context)

      if links.any?
        items = links.map do |l|
          href_part = "<#{l[:href]}>"
          tags = l.to_a.select { |k,_| k != :href }.map { |k,v| "#{k}=#{v}" }
          ([href_part] + tags).join('; ')
        end
        response.set_header('Link', items.join(', '))
      end

      if defined? @serialization_wrapping_renderer
        input = {
          identifier: identifier,
          registrations: registrations,
          output: result,
          links: links,
        }
        wrapped = @serialization_wrapping_renderer.serialize input, '*/*', context: self
        render body: wrapped
        # TODO: display identifiers

        response.content_type = 'text/html'
      end

      render body: result, **options

      # TODO: fix display identifiers, don't output Content-Type: */*
      response.content_type = identifier
    end
  end
end
