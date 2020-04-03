# frozen_string_literal: true

require 'delegate'

module MediaTypes
  module Serialization
    # Provides the serialization convenience methods
    class SerializationDSL < SimpleDelegator
      def initialize(serializer, links = [], vary = ['Accept'], value = {}, context: nil)
        self.serialization_dsl_result = value
        @serialization_links = links
        @serialization_context = context
        @serialization_vary = vary
        super(serializer)
      end

      attr_accessor :serialization_dsl_result

      def attribute(key, value = {}, &block)
        unless block.nil?
          subcontext = SerializationDSL.new(__getobj__, @serialization_links, @serialization_vary, value, context: @serialization_context)
          value = subcontext.instance_exec(&block)
        end

        serialization_dsl_result[key] = value

        serialization_dsl_result
      end

      def link(rel, href:, emit_header: true, **attributes)
        serialization_dsl_result[:_links] = {} unless serialization_dsl_result.has_key? :_links

        link = {
          href: href,
          rel: rel,
        }
        link = link.merge(attributes)

        json = {
          href: href,
        }
        json = json.merge(attributes)

        @serialization_links.append(link) if emit_header
        serialization_dsl_result[:_links][rel] = json

        serialization_dsl_result
      end

      def index(array, serializer = __getobj__, version:, view: nil)
        raise CollectionTypeError, array.class.name unless array.is_a? Array

        links = []
        identifier = serializer.serializer_validator.view(view).version(version).identifier

        array.each do |e|
          child_links = []
          context = SerializationDSL.new(__getobj__, child_links, context: @serialization_context)
          serializer.serialize(e, identifier, @serialization_context, dsl: context)

          self_links = child_links.select { |l| l[:rel] == :self }
          raise NoSelfLinkProvidedError, identifier unless self_links.any?
          raise MultipleSelfLinksProvidedError, identifier if self_links.length > 1

          links.append(self_links.first.reject { |k, _| k == :rel } )
        end

        serialization_dsl_result[:_index] = links

        serialization_dsl_result
      end

      def collection(array, serializer = __getobj__, version:, view: nil)
        raise CollectionTypeError, array.class.name unless array.is_a? Array

        identifier = serializer.serializer_validator.view(view).version(version).identifier

        rendered = []

        array.each do |e|
          context = SerializationDSL.new(__getobj__, [], @serialization_vary, context: @serialization_context)
          result = serializer.serialize(e, identifier, @serialization_context, dsl: context, raw: true)

          rendered.append(result)
        end

        serialization_dsl_result[:_embedded] = rendered

        serialization_dsl_result
      end

      def hidden(&block)
        context = SerializationDSL.new(__getobj__, @serialization_links, context: @serialization_context)
        context.instance_exec(&block)

        serialization_dsl_result
      end

      def render_view(name, context:, **args)
        context.render_to_string(name, **args)
      end

      def emit
        serialization_dsl_result
      end
      
      def object(&block)
        context = SerializationDSL.new(__getobj__, @serialization_links, @serialization_vary, context: @serialization_context)
        context.instance_exec(&block)

        context.serialization_dsl_result
      end
    end
  end
end
