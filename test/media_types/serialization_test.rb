require 'test_helper'

require 'abstract_controller/callbacks'
require 'abstract_controller/rendering'
require 'action_controller/metal'
require 'action_controller/metal/mime_responds'
require 'action_controller/metal/rendering'
require 'action_controller/metal/renderers'
require 'action_dispatch/http/request'
require 'action_dispatch/http/response'

require 'media_types'
require 'media_types/serialization/renderer/register'

require 'http_headers/accept'

require 'oj'

class MediaTypes::SerializationTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MediaTypes::Serialization::VERSION
  end

  class MyResourceMediaType
    include ::MediaTypes::Dsl

    def self.base_format
      'application/vnd.mydomain.%<type>s.v%<version>s.%<view>s+%<suffix>s'
    end

    media_type 'my_resource', defaults: { version: 1, suffix: :json }

    validations do
      version 1 do
        attribute :name
        attribute :number, Numeric
        collection :items, allow_empty: true do
          attribute :label
          attribute :data, Object
        end

        attribute :source, optional: true
      end
    end
  end

  class MyResourceSerializer < ::MediaTypes::Serialization::Base
    serializes_media_type MyResourceMediaType, additional_versions: [1]

    def to_hash
      {
        name: serializable[:title],
        number: serializable[:count],
        items: serializable[:data].map do |k, v|
          { label: k, data: v }
        end
      }
    end

    def to_xml(options = {})
      to_hash.merge(source: 'to_xml').to_xml(options)
    end

    def to_json(options = {})
      to_hash.merge(source: 'to_json').to_json(options)
    end

    def extract_view_links(*)
      { google: { href: 'https://google.com', foo: 'bar' } }
    end
  end

  class BaseController < ActionController::Metal
    include AbstractController::Callbacks
    include AbstractController::Rendering
    include ActionController::MimeResponds
    include ActionController::Rendering
    include ActionController::Renderers

    use_renderers :media

    include MediaTypes::Serialization
  end

  class FakeController < BaseController
    allow_output_serializer(MyResourceSerializer)
    allow_all_input
    freeze_io!

    def action
      input = request.body
      serializer = serialize_media(input)

      entries = serializer.to_link_header
      if entries.present?
        response.header['Link'] = entries
      end

      render media: serializer, content_type: request.format.to_s
    end
  end

  def setup
    @controller = FakeController.new
    @response = ActionDispatch::Response.new
  end

  def teardown
    Mime::Type.unregister(:my_special_symbol)
    MyResourceSerializer.undef_method :to_html if MyResourceSerializer.method_defined? :to_html
  end

  def test_it_serializes_via_serializer
    content_type = MyResourceMediaType.to_constructable.version(1).to_s
    Mime::Type.register(content_type, :my_special_symbol)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "my_resource" => { "name" => "test serialization", "number" => 1, "items" => [] } }, result )
  end

  def test_it_serializes_via_dedicated_method
    content_type = MyResourceMediaType.to_constructable.version(1).suffix(:xml).to_s
    Mime::Type.register(content_type, :my_special_symbol)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Hash.from_xml(@response.body)["hash"]
    assert_equal( { "name" => "test serialization", "number" => 1, "items" => [], "source" => "to_xml" }, result )
  end

  def test_it_only_serializes_what_it_knows
    content_type = 'text/html'
    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "application/vnd.mydomain.nope, text/html; q=0.1"
    })

    MyResourceSerializer.define_method :to_html do |options = {}|
      "<code>#{to_hash.merge(source: 'to_html').to_json(options)}</code>"
    end

    @controller.dispatch(:action, request, @response)

    assert_equal content_type, @response.content_type.split(';').first
    assert_equal '<code>{"name":"test serialization","number":1,"items":[],"source":"to_html"}</code>', @response.body
  end

  def test_it_uses_the_html_wrapper
    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "application/vnd.mydomain.nope, text/html; q=0.1"
    })

    assert_raises ActionView::MissingTemplate do
      @controller.dispatch(:action, request, @response)
    end
  end

  def test_it_uses_the_html_wrapper_for_the_api_viewer
    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "application/vnd.xpbytes.api-viewer.v1"
    })

    # Define it to ensure this was not used
    MyResourceSerializer.define_method :to_html do |options = {}|
      "<code>#{to_hash.merge(source: 'to_html').to_json(options)}</code>"
    end

    assert_raises ActionView::MissingTemplate do
      @controller.dispatch(:action, request, @response)
    end
  end

  def test_it_extracts_links
    content_type = MyResourceMediaType.to_constructable.version(1).to_s
    Mime::Type.register(content_type, :my_special_symbol)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:action, request, @response)
    assert_equal "<https://google.com>; rel=google; foo=bar", @response['Link']
  end
end

