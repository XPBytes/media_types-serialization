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

class MediaTypes::RootKeyTest < Minitest::Test

  class MyResourceMediaType
    include ::MediaTypes::Dsl

    def self.organisation
      'mydomain1'
    end

    use_name 'my_resource', defaults: { suffix: :json }

    validations do
      version 1 do
        attribute :name
        attribute :number, Numeric
        collection :items, allow_empty: true do
          attribute :label
          attribute :data, Object
        end

        attribute :source, optional: true

        view :collection do
          empty
        end

        view :special do
          empty
        end

        view :index do
          empty
        end
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
      return { href: '/index' } if view == ::MediaTypes::INDEX_VIEW
      { href: '/item' }
    end

    def extract_view_links(view: current_view)
      {
        self: extract_self(view: view),
        google: { href: 'https://google.com', foo: 'bar' }
      }
    end
  end

  class MySpecialResourceValidator
    include MediaTypes::Dsl

    def self.organisation
      'acme'
    end

    use_name 'my_resource', defaults: { suffix: :json }

    validations do
      view :special do
        version 1 do
          empty
        end
      end
    end
  end

  class MySpecialSerializer < MyResourceSerializer
    serializes_media_type MySpecialResourceValidator

    def self.root_key(*)
      :very_special
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
    allow_output_serializer(MyResourceSerializer, view: [nil, :index, :collection])
    allow_output_serializer(MySpecialSerializer, view: [:special])
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
    Mime::Type.unregister(:my)
    Mime::Type.unregister(:my_index)
    Mime::Type.unregister(:my_collection)
  end

  def test_it_serializes_with_as_singular_root_key
    content_type = MyResourceMediaType.version(1).identifier
    Mime::Type.register(content_type, :my)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => content_type
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first
    puts [content_type, @response.body].to_s

    result = Oj.load(@response.body)
    assert_equal( ['my_resource'], result.keys )
  end

  def test_it_pluralizes_index_view
    content_type = MyResourceMediaType.view(:index).version(1).identifier
    Mime::Type.register(content_type, :my_index)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => [{ title: 'test serialization', count: 1, data: {} }],
      'HTTP_ACCEPT' => content_type.to_s
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( ['my_resources'], result.keys )
  end

  def test_it_pluralizes_collection_view
    content_type = MyResourceMediaType.view(:collection).version(1).identifier
    Mime::Type.register(content_type, :my_collection)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => [{ title: 'test serialization', count: 1, data: {} }],
      'HTTP_ACCEPT' => content_type.to_s
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( ['my_resources'], result.keys )
  end

  def test_it_can_override_root_key
    content_type = MySpecialResourceValidator.version(1).view(:special).identifier
    puts content_type
    Mime::Type.register(content_type, :my)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => { title: 'test serialization', count: 1, data: {} },
      'HTTP_ACCEPT' => content_type.to_s
    })

    @controller.dispatch(:action, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( ['very_special'], result.keys )
  end
end

