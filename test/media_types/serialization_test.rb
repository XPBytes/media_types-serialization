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

require 'http_headers/accept'

require 'oj'

class MediaTypes::SerializationTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MediaTypes::Serialization::VERSION
  end

  class MyResourceMediaType
    include ::MediaTypes::Dsl

    def self.organisation
      'mydomain'
    end

    use_name 'my_resource'

    validations do
      version 1 do
        attribute :name
        attribute :number, Numeric
        link :google
        collection :items, allow_empty: true do
          attribute :label
          attribute :data, Object
        end

        attribute :source, optional: true
      end
    end
  end

  class MyResourceSerializer < ::MediaTypes::Serialization::Base
    validator MyResourceMediaType

    output version: 1 do |obj, version, context|
      obj = obj[:obj]
      attribute :name, obj[:title]
      attribute :number, obj[:count]
      attribute :items, (obj[:data].map do |k, v|
        { label: k, data: v }
      end)
      link :google, href: 'https://google.com', foo: 'bar'
    end

  end

  class BaseController < ActionController::Metal
    include AbstractController::Callbacks
    include AbstractController::Rendering
    include ActionController::MimeResponds
    include ActionController::Rendering
    include ActionController::Renderers

    include MediaTypes::Serialization
  end

  class FakeController < BaseController
    allow_output_serializer MyResourceSerializer
    freeze_io!

    def action
      input = request.body || true
      raise 'input nil' if input.nil?

      render_media input
    end
  end

  def setup
    @controller = FakeController.new
    @response = ActionDispatch::Response.new
  end

  def test_it_serializes_via_serializer
    content_type = MyResourceMediaType.version(1).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "name" => "test serialization", "number" => 1, "items" => [], "_links" => {"google" => {"href" => "https://google.com", "foo" => "bar"}} }, result )
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
    assert_equal 406, @response.status # not acceptable
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

