# frozen_string_literal: true

require 'media_types/serialization/error'
require 'media_types/serialization/fake_validator'
require 'media_types/serialization/serialization_registration'
require 'media_types/serialization/output_wrapper'

module MediaTypes
  module Serialization
    class Base

      @@serializer_validated = nil
      @@serializer_validator = nil
      @@serializer_input_registration = SerializationRegistration.new(:input)
      @@serializer_output_registration = SerializationRegistration.new(:output)

      def self.unvalidated(prefix)
        @@serializer_validated = false
        @@serializer_validator = FakeValidator.new(prefix)
      end

      def self.validator(validator)
        @@serializer_validated = true
        @@serializer_validator = validator
      end

      def self.output(view: nil, version: nil, versions: nil, &block)
        versions = [version] if versions == nil

        raise ValidatorNotSpecifiedError, :output if serializer_validator.nil?

        versions.each do |v|
          validator = @@serializer_validator.view(view).version(v)
          validator = validator.override_suffix(:json) unless @@serializer_validated
          identifier = validator.identifier

          serializer_output_registration.register_block(self, validator, v, block, false)
        end
      end

      def self.output_raw(view: nil, version: nil, versions: nil, &block)
        versions = [version] if versions == nil

        raise ValidatorNotSpecifiedError, :output if serializer_validator.nil?

        versions.each do |v|
          validator = @@serializer_validator.view(view).version(v)
          identifier = validator.identifier

          serializer_output_registration.register_block(self, validator, v, block, false)
        end
      end

      def self.output_alias(media_type_identifier, view: nil)
        validator = @@serializer_validator.view(view).version(v)
        victim_identifier = validator.identifier

        serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, false)
      end

      def self.output_alias_optional(media_type_identifier, view: nil)
        validator = @@serializer_validator.view(view).version(v)
        victim_identifier = validator.identifier

        serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, true)
      end
      
      def self.input(view: nil, version: nil, versions: nil, &block)
        versions = [version] if versions == nil

        raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

        versions.each do |v|
          validator = @@serializer_validator.view(view).version(v)
          validator = validator.override_suffix(:json) unless @@serializer_validated
          identifier = validator.identifier

          serializer_output_registration.register_block(self, validator, v, block, false)
        end
      end

      def self.input_raw(view: nil, version: nil, versions: nil, &block)
        versions = [version] if versions == nil

        raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

        versions.each do |v|
          validator = @@serializer_validator.view(view).version(v)
          identifier = validator.identifier

          serializer_input_registration.register_block(self, validator, v, block, false)
        end
      end

      def self.input_alias(media_type_identifier, view: nil)
        validator = @@serializer_validator.view(view).version(v)
        victim_identifier = validator.identifier

        serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, false)
      end

      def self.input_alias_optional(media_type_identifier, view: nil)
        validator = @@serializer_validator.view(view).version(v)
        victim_identifier = validator.identifier

        serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, true)
      end

      def self.serialize(victim, media_type, context: nil)
        raise "TODO: unimplemented"
      end

      def render_media(obj = nil, serializers: nil, not_acceptable_serializer: nil, **options, &block)
        raise "TODO: unimplemented"
        # if type == block
        # wrapper:
        # # attribute(key, value={}, &block)
        # # link(rel:, href:)
        # # index(array, serializer, view: nil)
        # # collection(array, serializer, view: nil)
        # # hidden do
      end

      def deserialize(request)
        raise "TODO: unimplemented"
      end

      def deserialize!(request)
        raise "TODO: unimplemented"
      end

      def resolve_serializer
        raise "TODO: unimplemented"
      end

    end
  end
end
