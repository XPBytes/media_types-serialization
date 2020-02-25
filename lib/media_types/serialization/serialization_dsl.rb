# frozen_string_literal: true

require 'delegator'

module MediaTypes
  module Serialization
    class SerializationDSL < SimpleDelegator

      def initialize(serializer, links = [], value = {}, context: nil)
        serialization_dsl_result = value
        @serialization_links = links
        @serialization_context = context
        super(serializer)
      end

      attr_accessor :serialization_dsl_result

      def attribute(key, value = {}, &block)
        unless block.nil?
          subcontext = SerializationDSL.new(__getobj__, links, value, context: @serialization_context)
          value = subcontext.instance_eval(block)
        end

        serialization_dsl_result[key] = value

        serialization_dsl_result
      end

      def link(rel:, href:, **opts)
        serialization_dsl_result[:_links] = {} unless serialization_dsl_result.has_key? :_links

        link = opts.dup
        link[:rel] = rel
        link[:href] = href

        json = opts.dup
        json[:href] = href

        @serialization_links.append(link)
        serialization_dsl_result[:_links][rel] = json

        serialization_dsl_result
      end

      def index(array, serializer, version:, view: nil)
        links = []
        identifier = serializer.validator.view(view).version(version).identifier

        array.each do |e|
          child_links = []
          context = SerializationDSL.new(__getobj__, child_links, context: @serialization_context)
          context.instance_eval labda { serializer.serialize(e, identifier, __getobj__, @serialization_context) }

          self_links = self_links.select { |l| l.rel == :self }
          raise NoSelfLinkProvidedError, identifier unless self_links.any?
          raise MultipleSelfLinksProvidedError, identifier if self_links.length > 1

          links.append(self_links.first)
        end

        serialization_dsl_result[:_index] = links

        serialization_dsl_result
      end
      
      def collection(array, serializer, version:, view: nil)
        identifier = serializer.validator.view(view).version(version).identifier

        rendered = []

        array.each do |e|
          context = SerializationDSL.new(__getobj__, context: @serialization_context)
          result = context.instance_eval labda { return serializer.serialize(e, identifier, __getobj__, @serialization_context) }

          rendered.append(result)
        end

        serialization_dsl_result[:_embed] = rendered

        serialization_dsl_result
      end

      def hidden(&block)
        context = SerializationDSL.new(__getobj__, @serialization_links, context: @serialization_context)

      end
    end
  end
end
