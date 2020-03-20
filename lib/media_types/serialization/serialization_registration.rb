# frozen_string_literal: true

require 'media_types/serialization/error'

module MediaTypes
  module Serialization
    # A collection that manages media type identifier registrations
    class SerializationRegistration
      def initialize(direction)
        self.registrations = {}
        self.inout = direction
      end

      attr_accessor :registrations, :inout

      def has?(identifier)
        registrations.key? identifier
      end

      def register_block(serializer, validator, version, block, raw, wildcards: true)
        identifier = validator.identifier

        raise DuplicateDefinitionError.new(identifier, inout) if registrations.key? identifier

        raise ValidatorNotDefinedError.new(identifier, inout) unless raw || validator.validatable?

        registration = SerializationBlockRegistration.new serializer, inout, validator, identifier, version, block, raw
        registrations[identifier] = registration

        register_wildcards(identifier, registration) if wildcards
      end

      def register_alias(serializer, alias_identifier, target_identifier, optional, wildcards: true, display_identifier: nil)
        raise DuplicateDefinitionError.new(identifier, inout) if registrations.key? alias_identifier

        raise UnbackedAliasDefinitionError.new(target_identifier, inout) unless registrations.key? target_identifier

        target = registrations[target_identifier]

        registration = SerializationAliasRegistration.new serializer, inout, target.validator, alias_identifier, target, optional
        registrations[alias_identifier] = registration

        register_wildcards(alias_identifier, registration) if wildcards
      end

      def merge(other)
        raise Error, 'Trying to merge two SerializationRegistration objects with a different direction.' unless inout == other.inout

        result = SerializationRegistration.new(inout)

        prev_keys = Set.new(registrations.keys)
        new_keys = Set.new(other.registrations.keys)
        overlap = prev_keys & new_keys

        result.registrations = registrations.merge(other.registrations)
        overlap.each do |identifier|
          prev_item = registrations[identifier]
          new_item = other.registrations[identifier]
          merge_result = prev_item.merge(new_item)

          raise DuplicateUsageError.new(identifier, inout, prev_item.serializer, new_item.serializer) if merge_result.nil?

          result.registrations[identifier] = merge_result
        end

        result
      end

      def decode(victim, media_type, context)
        registration = registrations[media_type]
        raise UnregisteredMediaTypeUsageError.new(media_type, registrations.keys) if registration.nil?

        registration.decode(victim, context)
      end

      def call(victim, media_type, context, dsl: nil, raw: nil)
        registration = registrations[media_type]
        raise UnregisteredMediaTypeUsageError.new(media_type, registrations.keys) if registration.nil?

        registration.call(victim, context, dsl: dsl, raw: raw)
      end

      def identifier_for(input_identifier)
        registration = registrations[input_identifier]
        raise UnregisteredMediaTypeUsageError.new(media_type, registrations.keys) if registration.nil?

        registration.display_identifier
      end

      def filter(views:)
        result = SerializationRegistration.new inout

        registrations.each do |identifier, registration|
          if views.include? registration.validator.view
            result.registrations[identifier] = registration
          end
        end

        result
      end

      private

      def register_wildcards(identifier, registration)
        new_alias = SerializationAliasRegistration.new registration.serializer, registration.inout, registration.validator, registration.display_identifier, registration, true

        registrations['*/*'] = new_alias unless has? '*/*'

        partial = "#{identifier.split('/')[0]}/*"
        registrations[partial] = new_alias unless has? partial
      end
    end

    # A registration in a SerializationRegistration collection
    class SerializationBaseRegistration
      def initialize(serializer, inout, validator, display_identifier)
        self.serializer = serializer
        self.inout = inout
        self.validator = validator
        self.display_identifier = display_identifier
      end

      def merge(_other)
        nil
      end

      def decode(_victim, _context)
        raise 'Assertion failed, decode function called on base registration.'
      end
      def call(_victim, _context, dsl: nil, raw: nil)
        raise 'Assertion failed, call function called on base registration.'
      end

      attr_accessor :serializer, :inout, :validator, :display_identifier
    end

    # A registration with a block to be executed when called.
    class SerializationBlockRegistration < SerializationBaseRegistration
      def initialize(serializer, inout, validator, display_identifier, version, block, raw)
        self.version = version
        self.block = block
        self.raw = raw
        super(serializer, inout, validator, display_identifier)
      end

      def decode(victim, context)
        raise CannotDecodeOutputError if inout != :input

        if !self.raw
          victim = MediaTypes::Serialization.json_decoder.call(victim)
          begin
            validator.validate!(victim)
          rescue ValidationError => inner
            raise InputValidationFailedError, inner
          end
        end

        victim
      end

      def call(victim, context, dsl: nil, raw: nil)
        raw = self.raw if raw.nil?

        result = nil
        if dsl.nil?
          result = block.call(victim, version, context)
        else
          result = dsl.instance_exec victim, version, context, &block
        end

        if !raw && inout == :output
          begin
            validator.validate!(result)
          rescue MediaTypes::Scheme::ValidationError => inner
            raise OutputValidationFailedError, inner
          end
          result = MediaTypes::Serialization.json_encoder.call(result)
        end

        result
      end

      attr_accessor :version, :block, :raw
    end

    # A registration that calls another registration when called.
    class SerializationAliasRegistration < SerializationBaseRegistration
      def initialize(serializer, inout, validator, display_identifier, target, optional)
        self.target = target
        self.optional = optional
        super(serializer, inout, validator, display_identifier)
      end

      def merge(other)
        return nil unless other.is_a?(SerializationAliasRegistration)

        unless optional
          return nil unless other.optional # two non-optional can't merge
          return self
        end

        other # if both optional, or other is !optional, newer one wins.
      end

      def decode(victim, context)
        target.decode(victim, context)
      end

      def call(victim, context, dsl: nil, raw: nil)
        target.call(victim, context, dsl: dsl, raw: raw)
      end

      attr_accessor :target, :optional
    end
  end
end
