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
          self.serializer_input_registrations = {}
          self.serializer_output_registrations = {}
        end

        def validator(validator = nil)
          raise NoValidatorSetError if !defined? serializer_validator && validator.nil?
          return serializer_validator if validator.nil?

          self.serializer_validated = true
          self.serializer_validator = validator
          self.serializer_input_registrations = {}
          self.serializer_output_registrations = {}
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

          unless serializer_output_registrations.has_key? view
            serializer_output_registrations[view] = SerializationRegistration.new(:output)
          end

          versions.each do |v|
            validator = serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless serializer_validated

            serializer_output_registrations[view].register_block(
              self,
              validator,
              v,
              block,
              false,
              wildcards:
              !serializer_disable_wildcards
            )
          end
        end

        def output_raw(view: nil, version: nil, versions: nil, suffix: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :output if serializer_validator.nil?

          unless serializer_output_registrations.has_key? view
            serializer_output_registrations[view] = SerializationRegistration.new(:output)
          end

          versions.each do |v|
            validator = serializer_validator.view(view)
                                            .version(v)
                                            .override_suffix(suffix)

            serializer_output_registrations[view].register_block(
              self,
              validator,
              v,
              block,
              true,
              wildcards: !serializer_disable_wildcards
            )
          end
        end

        def output_alias(
          media_type_identifier,
          view: nil,
          suffix: media_type_identifier == 'application/json' || media_type_identifier.end_with?('+json') ? :json : nil,
          hide_variant: false
        )
          validator = serializer_validator.view(view).override_suffix(suffix)
          victim_identifier = validator.identifier

          unless serializer_output_registrations.has_key? view
            serializer_output_registrations[view] = SerializationRegistration.new(:output)
          end

          serializer_output_registrations[view].register_alias(
            self,
            media_type_identifier,
            victim_identifier,
            false,
            hide_variant,
            wildcards: !serializer_disable_wildcards
          )
        end

        def output_alias_optional(
          media_type_identifier,
          view: nil,
          suffix: media_type_identifier == 'application/json' || media_type_identifier.end_with?('+json') ? :json : nil,
          hide_variant: false
        )
          validator = serializer_validator.view(view).override_suffix(suffix)
          victim_identifier = validator.identifier

          unless serializer_output_registrations.has_key? view
            serializer_output_registrations[view] = SerializationRegistration.new(:output)
          end

          serializer_output_registrations[view].register_alias(
            self,
            media_type_identifier,
            victim_identifier,
            true,
            hide_variant,
            wildcards: !serializer_disable_wildcards
          )
        end

        def input(view: nil, version: nil, versions: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          unless serializer_input_registrations.has_key? view
            serializer_input_registrations[view] = SerializationRegistration.new(:input)
          end

          versions.each do |v|
            validator = serializer_validator.view(view).version(v)
            validator.override_suffix(:json) unless serializer_validated

            serializer_input_registrations[view].register_block(self, validator, v, block, false)
          end
        end

        def input_raw(view: nil, version: nil, versions: nil, suffix: nil, &block)
          versions = [version] if versions.nil?
          raise VersionsNotAnArrayError unless versions.is_a? Array

          raise ValidatorNotSpecifiedError, :input if serializer_validator.nil?

          unless serializer_input_registrations.has_key? view
            serializer_input_registrations[view] = SerializationRegistration.new(:input)
          end

          versions.each do |v|
            validator = serializer_validator.view(view).version(v).override_suffix(suffix)

            serializer_input_registrations[view].register_block(self, validator, v, block, true)
          end
        end

        def input_alias(
          media_type_identifier,
          view: nil,
          suffix: media_type_identifier == 'application/json' || media_type_identifier.end_with?('+json') ? :json : nil
        )
          validator = serializer_validator.view(view).override_suffix(suffix)
          victim_identifier = validator.identifier

          unless serializer_input_registrations.has_key? view
            serializer_input_registrations[view] = SerializationRegistration.new(:input)
          end

          serializer_input_registrations[view].register_alias(
            self,
            media_type_identifier,
            victim_identifier,
            false,
            true,
            wildcards: false
          )
        end

        def input_alias_optional(
          media_type_identifier,
          view: nil,
          suffix: media_type_identifier == 'application/json' || media_type_identifier.end_with?('+json') ? :json : nil
        )
          validator = serializer_validator.view(view).override_suffix(suffix)
          victim_identifier = validator.identifier

          unless serializer_input_registrations.has_key? view
            serializer_input_registrations[view] = SerializationRegistration.new(:input)
          end

          serializer_input_registrations[view].register_alias(
            self,
            media_type_identifier,
            victim_identifier,
            true,
            true,
            wildcards: false
          )
        end

        def serialize(victim, media_type_identifier, context:, dsl: nil, raw: nil)
          dsl ||= SerializationDSL.new(self, context: context)
          
          merged_output_registrations = SerializationRegistration.new(:output)
          serializer_output_registrations.keys.each do |k|
            merged_output_registrations = merged_output_registrations.merge(serializer_output_registrations[k])
          end

          merged_output_registrations.call(victim, media_type_identifier.to_s, context, dsl: dsl, raw: raw)
        end

        def deserialize(victim, media_type_identifier, context:)
          merged_input_registrations = SerializationRegistration.new(:input)
          serializer_input_registrations.keys.each do |k|
            merged_input_registrations = merged_input_registrations.merge(serializer_input_registrations[k])
          end

          merged_input_registrations.call(victim, media_type_identifier, context)
        end

        def outputs_for(views:)
          merged_output_registrations = SerializationRegistration.new(:output)
          views.each do |k|
            merged_output_registrations = merged_output_registrations.merge(serializer_output_registrations[k]) if serializer_output_registrations.has_key?(k)
          end
          
          merged_output_registrations
        end

        def inputs_for(views:)
          merged_input_registrations = SerializationRegistration.new(:input)
          views.each do |k|
            merged_input_registrations = merged_input_registrations.merge(serializer_input_registrations[k]) if serializer_input_registrations.has_key?(k)
          end

          merged_input_registrations
        end
      end

      def self.inherited(subclass)
        super

        subclass.extend(ClassMethods)
        subclass.instance_eval do
          class << self
            attr_accessor :serializer_validated
            attr_accessor :serializer_validator
            attr_accessor :serializer_input_registrations
            attr_accessor :serializer_output_registrations
            attr_accessor :serializer_disable_wildcards
          end
        end
      end
    end
  end
end
