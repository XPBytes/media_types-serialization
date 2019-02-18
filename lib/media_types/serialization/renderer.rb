require 'media_types/serialization/no_content_type_given'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/conversions'

module MediaTypes
  module Serialization
    # noinspection RubyConstantNamingConvention
    Renderer = lambda do |obj, options|
      content_type = options[:content_type] || options[:mime_type]&.to_s || self.content_type&.to_s || obj.current_media_type.to_s
      raise NoContentTypeGiven if content_type.blank?

      self.content_type ||= content_type

      if content_type.ends_with?('+json') || Mime::Type.lookup(content_type) == Mime[:json]
        obj.class.instance_methods(false).include?(:to_json) ? obj.to_json(options) : obj.to_hash.to_json(options)
      elsif content_type.ends_with?('+xml') || Mime::Type.lookup(content_type) == Mime[:xml]
        obj.class.instance_methods(false).include?(:to_xml) ? obj.to_xml(options) : obj.to_hash.to_xml(options)
      elsif Mime::Type.lookup(content_type) == Mime[:html]
        obj.class.instance_methods(false).include?(:to_html) ? obj.to_html : obj.to_s
      else
        obj.to_body(content_type: options.delete(:content_type) || content_type, **options)
      end
    end

    module_function

    def register_renderer
      ::ActionController::Renderers.add :media, &Renderer
    end
  end
end
