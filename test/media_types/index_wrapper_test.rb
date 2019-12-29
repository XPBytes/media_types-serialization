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

class MediaTypes::IndexWrapperTest < Minitest::Test

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

    def extract_self(view: current_view)
      return { href: '/item/for/index/view' } if view == ::MediaTypes::INDEX_VIEW
      { href: '/item' }
    end

    def extract_set_links(view: current_view)
      { href: '/path/to/index' }
    end

    def extract_links
      {
        self: extract_self(view: view),
        google: { href: 'https://google.com', foo: 'bar' }
      }
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
    allow_output_serializer(MyResourceSerializer, view: [:index])
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
    Mime::Type.unregister(:my_index)
    ::MediaTypes::Serialization.collect_links_for_index = false
  end

  def create_request(content_type)
    ActionDispatch::Request.new({
      Rack::RACK_INPUT => [{ title: 'first', count: 1, data: {} }, { title: 'another', count: 32, data: {} }],
      'HTTP_ACCEPT' => content_type.to_s
    })
  end

  def do_request_chain(content_type, request: create_request(content_type))
    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first
  end

  def test_it_only_serializes_links
    content_type = MyResourceMediaType.to_constructable.view(:index).version(1).to_s
    Mime::Type.register(content_type, :my_index)

    do_request_chain(content_type)

    result = Oj.load(@response.body).values.first
    assert_includes(result.keys, '_index')
    assert_equal([{"href"=>"/item/for/index/view"}, {"href"=>"/item/for/index/view"}], result['_index'] )
  end

  def test_it_only_extracts_the_index_link
    content_type = MyResourceMediaType.to_constructable.view(:index).version(1).to_s
    Mime::Type.register(content_type, :my_index)

    do_request_chain(content_type)

    assert_equal("</path/to/index>; rel=href", @response['Link'])
  end

  def test_it_can_serialize_index_links_into_the_body
    ::MediaTypes::Serialization.collect_links_for_index = true

    content_type = MyResourceMediaType.to_constructable.view(:index).version(1).to_s
    Mime::Type.register(content_type, :my_index)

    do_request_chain(content_type)
    result = Oj.load(@response.body).values.first

    assert_includes(result.keys, '_index')
    assert_equal([{"href"=>"/item/for/index/view"}, {"href"=>"/item/for/index/view"}], result['_index'] )

    assert_includes(result.keys, '_links')
    assert_equal({"href"=>"/path/to/index"}, result['_links'])
  end


  def test_it_coerces_data_into_collection
    content_type = MyResourceMediaType.to_constructable.view(:index).version(1).to_s
    Mime::Type.register(content_type, :my_index)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'first', count: 1, data: {} },
      'HTTP_ACCEPT' => content_type.to_s
    })
    do_request_chain(content_type, request: request)
    result = Oj.load(@response.body).values.first

    assert_includes(result.keys, '_index')
    assert_equal([{"href"=>"/item/for/index/view"}], result['_index'] )

  end
end

