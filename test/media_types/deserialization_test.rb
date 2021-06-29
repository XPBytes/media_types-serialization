require 'test_helper'

require 'active_support/callbacks'
require 'abstract_controller/callbacks'
require 'abstract_controller/rendering'
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

class MediaTypes::DeserializationTest < Minitest::Test
  class MyResourceMediaType
    include ::MediaTypes::Dsl

    def self.organisation
      'mydomain'
    end

    use_name 'my_resource'

    validations do
      view 'raw' do
        version 2 do
        end
      end
      version 2 do
      end
      version 1 do
        empty
      end
    end
  end

  class MyResourceSerializer < ::MediaTypes::Serialization::Base
    validator MyResourceMediaType

    output version: 1 do |_obj, version, context|
      {}
    end

    input version: 1 do |obj, version, context|
      obj
    end
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

  class FakeStrictController < BaseController
    allow_output_serializer(MyResourceSerializer)
    freeze_io!

    def action
      render_media {}
    end
  end

  class FakeFilteredController < BaseController
    allow_output_serializer(MyResourceSerializer)
    allow_input_serializer(MyResourceSerializer)
    freeze_io!

    def action
      render media: {}, content_type: request.format.to_s
    end
  end

  def setup
    @strict_controller = FakeStrictController.new
    @filtered_controller = FakeFilteredController.new
    @response = ActionDispatch::Response.new
  end

  def teardown
    Mime::Type.unregister(:my_special_symbol)
    MyResourceSerializer.undef_method :to_html if MyResourceSerializer.method_defined? :to_html
  end

  def test_it_block_unknown_input
    content_type = MyResourceMediaType.to_constructable.version(1).to_s
    Mime::Type.register(content_type, :my_special_symbol)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => StringIO.new({}.to_json),
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1",
    })
    request.headers['Content-Type'] = content_type

    #assert_raises MediaTypes::Serialization::NoInputSerializerError do
    #  @strict_controller.dispatch(:action, request, @response)
    #end
  end

  def test_it_allows_known_input
    content_type = MyResourceMediaType.to_constructable.version(1).to_s
    Mime::Type.register(content_type, :my_special_symbol)

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => StringIO.new({}.to_json),
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1",
    })
    request.headers['Content-Type'] = content_type

    @filtered_controller.dispatch(:action, request, @response)
  end
end

