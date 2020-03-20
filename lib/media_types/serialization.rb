require 'media_types/serialization/version'
require 'media_types/serialization/serializers/common_css'
require 'media_types/serialization/serializers/fallback_not_acceptable_serializer'
require 'media_types/serialization/serializers/fallback_unsupported_media_type_serializer'
require 'media_types/serialization/serializers/endpoint_description_serializer'
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
    self.value = block.nil? ? obj : yield
  end
end

module MediaTypes
  module Serialization

    HEADER_ACCEPT = 'HTTP_ACCEPT'

    mattr_accessor :json_encoder, :json_decoder
    if defined?(::Oj)
      self.json_encoder = ->(obj) {
        Oj.dump(obj,
          mode:       :compat,
          indent:     '  ',
          space:      ' ',
          array_nl:   "\n",
          object_nl:  "\n",
          ascii_only: false,
          allow_nan:  false,
        )
      }
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
        raise ViewsNotAnArrayError unless views.is_a? Array

        before_action do
          @serialization_available_serializers ||= {}
          @serialization_available_serializers[:output] ||= {}
          actions = filter_opts[:only] || :all_actions
          actions = [actions] unless actions.is_a?(Array)
          actions.each do |action|
            @serialization_available_serializers[:output][action.to_s] ||= []
            views.each do |v|
              @serialization_available_serializers[:output][action.to_s].push({serializer: serializer, view: v})
            end
          end
        end

        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_output_registrations ||= SerializationRegistration.new(:output)

          mergeable_outputs = serializer.outputs_for(views: views)
          raise AddedEmptyOutputSerializer if mergeable_outputs.registrations.empty?

          @serialization_output_registrations = @serialization_output_registrations.merge(mergeable_outputs)
        end
      end
      
      def allow_api_viewer(serializer: MediaTypes::Serialization::Serializers::ApiViewer, **filter_opts)
        before_action do
          @serialization_api_viewer_enabled ||= {}
          actions = filter_opts[:only] || :all_actions
          actions = [actions] unless actions.kind_of?(Array)
          actions.each do |action|
            @serialization_api_viewer_enabled[action.to_s] = true
          end
        end

        before_action(**filter_opts) do
          if request.query_parameters['api_viewer']
            @serialization_override_accept = request.query_parameters['api_viewer'].sub ' ', '+'
            @serialization_wrapping_renderer = serializer
          end
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
        raise SerializersAlreadyFrozenError if defined? @serialization_frozen
        raise ArrayInViewParameterError, :allow_input_serializer if view.is_a? Array
        views = [view] if views.nil?
        raise ViewsNotAnArrayError unless views.is_a? Array
        
        before_action do
          @serialization_available_serializers ||= {}
          @serialization_available_serializers[:input] ||= {}
          actions = filter_opts[:only] || :all_actions
          actions = [actions] unless actions.is_a?(Array)
          actions.each do |action|
            @serialization_available_serializers[:input][action.to_s] ||= []
            views.each do |v|
              @serialization_available_serializers[:input][action.to_s].push({serializer: serializer, view: v})
            end
          end
        end

        before_action(**filter_opts) do
          raise SerializersAlreadyFrozenError if defined? @serialization_frozen

          @serialization_input_registrations ||= SerializationRegistration.new(:input)

          mergeable_inputs = serializer.inputs_for(views: views)
          raise AddedEmptyInputSerializer if mergeable_inputs.registrations.empty?

          @serialization_input_registrations = @serialization_input_registrations.merge(mergeable_inputs)
        end
      end

      def allow_all_output(**filter_opts)
        before_action(**filter_opts) do
          @serialization_output_allow_all ||= true
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
        before_action :serializer_freeze_io_internal
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

    def render_media(obj, serializers: nil, not_acceptable_serializer: nil, **options, &block)
      raise SerializersNotFrozenError unless defined? @serialization_frozen

      not_acceptable_serializer ||= @serialization_not_acceptable_serializer if defined? @serialization_not_acceptable_serializer

      @serialization_output_registrations ||= SerializationRegistration.new(:output)
      registration = @serialization_output_registrations
      unless serializers.nil?
        registration = SerializationRegistration.new(:output)
        serializers.each do |s|
          registration = registration.merge(s)
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
      raise InputNotAcceptableError unless @serialization_input_registrations.has? request.content_type
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

    def resolve_media_type(request, registration, allow_last: true)
      if defined? @serialization_override_accept
        @serialization_override_accept = registration.registrations.keys.last if allow_last && @serialization_override_accept == 'last'
        return nil unless registration.has? @serialization_override_accept
        return @serialization_override_accept
      end

      # Ruby negotiation
      #
      # This is similar to the respond_to logic. It sorts the accept values and tries to match against each option.
      #
      #

      accept_header = HttpHeaders::Accept.new(request.get_header(HEADER_ACCEPT)) || ''
      accept_header.each do |mime_type|
        stripped = mime_type.to_s.split(';')[0]
        next unless registration.has? stripped

        return stripped
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

    def serializer_freeze_io_internal
      raise UnableToRefreezeError if defined? @serialization_frozen

      @serialization_frozen = true
      @serialization_input_registrations ||= SerializationRegistration.new(:input)

      raise NoOutputSerializersDefinedError unless defined? @serialization_output_registrations

      # Input content-type negotiation and validation
      all_allowed = false
      all_allowed ||= @serialization_input_allow_all if defined?(@serialization_input_allow_all)

      input_is_allowed = true
      input_is_allowed = @serialization_input_registrations.has? request.content_type unless request.content_type.blank?

      unless input_is_allowed || all_allowed
        serializers = @serialization_unsupported_media_type_serializer || [MediaTypes::Serialization::Serializers::FallbackUnsupportedMediaTypeSerializer]
        registrations = SerializationRegistration.new(:output)
        serializers.each do |s|
          registrations = registrations.merge(s.outputs_for(views: [nil]))
        end

        input = {
          registrations: @serialization_input_registrations
        }

        render_media input, serializers: [registrations]
        return
      end

      if input_is_allowed && request.content_type
        begin
          @serialization_decoded_input = @serialization_input_registrations.decode(request.body, request.content_type, self)
        rescue InputValidationFailedError => e
          raise e
          raise 'TODO: render with validation failed serializer'
        end
      end

      # Endpoint description media type

      description_serializer = MediaTypes::Serialization::Serializers::EndpointDescriptionSerializer

      # All endpoints have endpoint description.
      # Placed in front of the list to make sure the api viewer doesn't pick it.
      @serialization_output_registrations = description_serializer.outputs_for(views: [nil]).merge(@serialization_output_registrations)

      endpoint_matched_identifier = resolve_media_type(request, description_serializer.serializer_output_registration, allow_last: false)
      if endpoint_matched_identifier
        # We picked an endpoint description media type
        #
        @serialization_available_serializers ||= {}
        @serialization_available_serializers[:output] ||= {}
        @serialization_api_viewer_enabled ||= {}

        input = {
          api_viewer: @serialization_api_viewer_enabled,
          actions: @serialization_available_serializers,
        }

        serialization_render_resolved obj: input, serializer: description_serializer, identifier: endpoint_matched_identifier, registrations: @serialization_output_registrations, options: {}
        return
      end

      # Output content negotiation
      resolved_identifier = resolve_media_type(request, @serialization_output_registrations)

      not_acceptable_serializer = nil
      not_acceptable_serializer = @serialization_not_acceptable_serializer if defined? @serialization_not_acceptable_serializer
      not_acceptable_serializer ||= MediaTypes::Serialization::Serializers::FallbackNotAcceptableSerializer

      can_satisfy_allow = !resolved_identifier.nil?
      can_satisfy_allow ||= @serialization_output_allow_all if defined?(@serialization_output_allow_all)

      serialization_render_not_acceptable(@serialization_output_registrations, not_acceptable_serializer) unless can_satisfy_allow
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
        wrapped = @serialization_wrapping_renderer.serialize input, '*/*', self
        render body: wrapped

        response.content_type = 'text/html'
        return
      end

      render body: result, **options

      response.content_type = registrations.identifier_for(identifier)
    end
  end
end
