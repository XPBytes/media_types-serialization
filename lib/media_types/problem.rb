# frozen_string_literal: true

require 'erb'

module MediaTypes
  class Problem

    def initialize(error)
      self.error = error
      self.translations = {}
      self.custom_attributes = {}
      self.response_status_code = 400
    end

    attr_accessor :error, :translations, :custom_type, :custom_attributes, :response_status_code

    def type
      return custom_type unless custom_type.nil?

      "https://docs.delftsolutions.nl/wiki/Error/#{ERB::Util::url_encode(error.class.name)}"
    end

    def url(href)
      self.custom_type = href
    end

    def title(title, lang:)
      translations[lang] ||= {}
      translations[lang][:title] = title
    end

    def override_detail(detail, lang:)
      raise 'Unable to override detail message without having a title in the same language.' unless translations[lang]
      translations[lang][:detail] = title
    end

    def attribute(name, value)
      str_name = name.to_s

      raise "Unable to add an attribute with name '#{str_name}'. Name should start with a letter, consist of the letters A-Z, a-z, 0-9 or _ and be at least 3 characters long." unless str_name =~ /^[a-zA-Z][a-zA-Z0-9_]{2,}$/

      custom_attributes[str_name] = value
    end

    def status_code(code)
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[code] if code.is_a? Symbol

      self.response_status_code = code
    end

    def instance
      return nil unless custom_type.nil?

      inner = error.cause
      return nil if inner.nil?

      "https://docs.delftsolutions.nl/wiki/Error/#{ERB::Util::url_encode(inner.class.name)}"
    end

    def languages
      translations.keys
    end
  end
end
