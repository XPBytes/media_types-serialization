# frozen_string_literal: true

require 'media_types/serialization/error'
require 'media_types/serialization/fake_validator'
require 'media_types/serialization/serialization_registration'

module MediaTypes
  module Serialization
    class Base
      @@serializer_validated = nil
      @@serializer_validator = nil
      @@serializer_input_registration = nil
      @@serializer_output_registration = nil

      module ClassMethods
        def unvalidated(prefix)
          @@serializer_validated = false
          @@serializer_validator = FakeValidator.new(prefix)
          @@serializer_input_registration = SerializationRegistration.new(:input)
          @@serializer_output_registration = SerializationRegistration.new(:output)
        end

        def validator(validator = nil)
          raise NoValidatorSetError if @@serializer_validator.nil? && validator.nil?
          return @@serializer_validator if validator.nil?

          @@serializer_validated = true
          @@serializer_validator = validator
          @@serializer_input_registration = SerializationRegistration.new(:input)
          @@serializer_output_registration = SerializationRegistration.new(:output)
        end

        def output(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?

          raise ValidatorNotSpecifiedError, :output if @@serializer_validator.nil?

          versions.each do |v|
            validator = @@serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless @@serializer_validated
            identifier = validator.identifier

            @@serializer_output_registration.register_block(self, validator, v, block, false)
          end
        end

        def output_raw(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?

          raise ValidatorNotSpecifiedError, :output if @@serializer_validator.nil?

          versions.each do |v|
            validator = @@serializer_validator.view(view).version(v)
            identifier = validator.identifier

            @@serializer_output_registration.register_block(self, validator, v, block, false)
          end
        end

        def output_alias(media_type_identifier, view: nil)
          validator = @@serializer_validator.view(view).version(v)
          victim_identifier = validator.identifier

          @@serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, false)
        end

        def output_alias_optional(media_type_identifier, view: nil)
          validator = @@serializer_validator.view(view).version(v)
          victim_identifier = validator.identifier

          @@serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, true)
        end

        def input(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          versions.each do |v|
            validator = @@serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless @@serializer_validated

            @@serializer_output_registration.register_block(self, validator, v, block, false)
          end
        end

        def input_raw(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          versions.each do |v|
            validator = @@serializer_validator.view(view).version(v)

            @@serializer_input_registration.register_block(self, validator, v, block, false)
          end
        end

        def input_alias(media_type_identifier, view: nil)
          validator = @@serializer_validator.view(view).version(v)
          victim_identifier = validator.identifier

          @@serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, false)
        end

        def input_alias_optional(media_type_identifier, view: nil)
          validator = @@serializer_validator.view(view).version(v)
          victim_identifier = validator.identifier

          @@serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, true)
        end

        def serialize(victim, media_type_identifier, context)
          @@serializer_output_registration.call(victim, media_type_identifier, context)
        end

        def deserialize(victim, media_type_identifier, context)
          @@serializer_input_registration.call(victim, media_type_identifier, context)
        end

        def outputs_for(views:)
          @@serializer_output_registration.filter(views: views)
        end

        def inputs_for(views:)
          @@serializer_input_registration.filter(views: views)
        end
      end

      def self.inherited(subclass)
        subclass.extend(ClassMethods)
      end
    end
  end
end
