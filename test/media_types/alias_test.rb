require 'test_helper'

require 'active_support/callbacks'
require 'abstract_controller/callbacks'
require 'abstract_controller/rendering'
require 'rack/utils'
require 'rack/response'
require 'action_dispatch/http/content_security_policy'
require 'action_controller'
require 'action_controller/metal'
require 'action_controller/metal/mime_responds'
require 'action_controller/metal/rendering'
require 'action_controller/metal/renderers'
require 'action_dispatch/http/request'
require 'action_dispatch/http/response'

require 'media_types'

require 'oj'

class MediaTypes::AliasTest < Minitest::Test
  class ConfigurationValidator
    include MediaTypes::Dsl

    def self.organisation
      'soundersmusic'
    end

    use_name 'configuration'

    validations do
      version 1 do
        attribute :configuration do
          link :self
        end
      end

      view :legacy do
        attribute :legacy, TrueClass
      end
    end
  end

  class ConfigurationSerializer < ::MediaTypes::Serialization::Base
    validator ConfigurationValidator

    # outputs with a Content-Type of application/vnd.soundersmusic.configuration.v1+json
    output version: 1 do |_, __, ___|
      attribute :configuration do
        link :self, href: 'https://example.org'
      end
    end

    # outputs with a Content-Type of application/vnd.soundersmusic.configuration.legacy+json
    output view: :legacy do |obj, _, __|
      attribute :legacy, true
    end
    output_alias 'application/json', view: :legacy

    output_raw view: :html do |obj, context|
      json = ConfigurationSerializer.serialize(
        obj,
        ConfigurationValidator.version(1),
        context: context
      )

      "<html lang='en'>\n" \
      " <head>\n" \
      "   <title>My simple api viewer</title>\n" \
      " </head>\n" \
      " <body>\n" \
      "   <pre><code>#{json}</code></pre>\n" \
      " </body>\n" \
      "</html>\n"
    end
    output_alias 'text/html', view: :html
  end


  class BaseController < ActionController::Metal
    include AbstractController::Callbacks
    include AbstractController::Rendering
    include ActionController::MimeResponds
    include ActionController::Rendering
    include ActionController::Renderers
    include ActiveSupport::Rescuable

    include MediaTypes::Serialization
  end

  class FakeController < BaseController
    allow_output_serializer(ConfigurationSerializer, views: %i[html legacy], only: %i[show])
    allow_output_serializer(ConfigurationSerializer, only: %i[show])
    freeze_io!

    def show
      render_media nil
    end
  end

  def setup
    @controller = FakeController.new
    @response = ActionDispatch::Response.new
  end

  def test_json_unaliased
    content_type = 'application/vnd.soundersmusic.configuration.legacy+json'

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => content_type
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first
    assert !@response.content_type.include?('variant'),
           "'#{@response.content_type}' should not contain variant"
  end

  def test_json_alias
    content_type = 'application/json'

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => content_type
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first
    assert @response.content_type.include?('variant=application/vnd.soundersmusic.configuration.legacy+json'),
           "'#{content_type}' does not contain variant"
  end

  def test_raw_alias
    content_type = 'text/html'

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first
    assert @response.content_type.include?('variant=application/vnd.soundersmusic.configuration.html'),
           "'#{content_type}' does not contain variant"
  end
end
