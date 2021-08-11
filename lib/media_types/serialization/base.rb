# frozen_string_literal: true

require 'media_types/serialization/error'
require 'media_types/serialization/fake_validator'
require 'media_types/serialization/serialization_registration'
require 'media_types/serialization/serialization_dsl'

module MediaTypes
  module Serialization
    class Base
      module ClassMethods
        def unvalidated(prefix)
          self.serializer_validated = false
          self.serializer_validator = FakeValidator.new(prefix)
          self.serializer_input_registration = SerializationRegistration.new(:input)
          self.serializer_output_registration = SerializationRegistration.new(:output)
        end

        def validator(validator = nil)
          raise NoValidatorSetError if !defined? serializer_validator && validator.nil?
          return serializer_validator if validator.nil?

          self.serializer_validated = true
          self.serializer_validator = validator
          self.serializer_input_registration = SerializationRegistration.new(:input)
          self.serializer_output_registration = SerializationRegistration.new(:output)
        end

        def disable_wildcards
          self.serializer_disable_wildcards = true
        end

        def enable_wildcards
          self.serializer_disable_wildcards = false
        end

        def output(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :output if serializer_validator.nil?

          versions.each do |v|
            validator = serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless serializer_validated

            serializer_output_registration.register_block(self, validator, v, block, false, wildcards: !self.serializer_disable_wildcards)
          end
        end

        def output_raw(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :output if serializer_validator.nil?

          versions.each do |v|
            validator = serializer_validator.view(view).version(v).override_suffix('')

            serializer_output_registration.register_block(self, validator, v, block, true, wildcards: !self.serializer_disable_wildcards)
          end
        end

        def output_alias(media_type_identifier, view: nil, hide_variant: false)
          validator = serializer_validator.view(view)
          victim_identifier = validator.identifier

          serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, false, hide_variant, wildcards: !self.serializer_disable_wildcards)
        end

        def output_alias_optional(media_type_identifier, view: nil, hide_variant: false)
          validator = serializer_validator.view(view)
          victim_identifier = validator.identifier

          serializer_output_registration.register_alias(self, media_type_identifier, victim_identifier, true, hide_variant, wildcards: !self.serializer_disable_wildcards)
        end

        def input(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          versions.each do |v|
            validator = serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless serializer_validated

            serializer_input_registration.register_block(self, validator, v, block, false)
          end
        end

        def input_raw(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          versions.each do |v|
            validator = serializer_validator.view(view).version(v)

            serializer_input_registration.register_block(self, validator, v, block, true)
          end
        end

        def input_alias(media_type_identifier, view: nil)
          validator = serializer_validator.view(view)
          victim_identifier = validator.identifier

          serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, false, true, wildcards: false)
        end

        def input_alias_optional(media_type_identifier, view: nil)
          validator = serializer_validator.view(view)
          victim_identifier = validator.identifier

          serializer_input_registration.register_alias(self, media_type_identifier, victim_identifier, true, true, wildcards: false)
        end

        def serialize(victim, media_type_identifier, context:, dsl: nil, raw: nil)
          dsl ||= SerializationDSL.new(self, context: context)
          serializer_output_registration.call(victim, media_type_identifier.to_s, context, dsl: dsl, raw: raw)
        end

        def deserialize(victim, media_type_identifier, context:)
          serializer_input_registration.call(victim, media_type_identifier, context)
        end

        def outputs_for(views:)
          serializer_output_registration.filter(views: views)
        end

        def inputs_for(views:)
          serializer_input_registration.filter(views: views)
        end
      end

      def self.inherited(subclass)
        subclass.extend(ClassMethods)
        subclass.instance_eval do
          class << self
            attr_accessor :serializer_validated
            attr_accessor :serializer_validator
            attr_accessor :serializer_input_registration
            attr_accessor :serializer_output_registration
            attr_accessor :serializer_disable_wildcards
          end
        end
      end
    end
  end
end
