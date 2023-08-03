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

class MediaTypes::LooseTest < Minitest::Test
  class MyResourceMediaType
    include ::MediaTypes::Dsl

    def self.organisation
      'mydomain'
    end

    use_name 'my_resource'

    validations do
      version 1 do
        link :self, optional: :loose
        link :example

        attribute :test
      end
    end
  end

  class MyResourceSerializer < ::MediaTypes::Serialization::Base
    validator MyResourceMediaType

    output version: 1 do |obj, version, context|
      obj
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
    allow_input_serializer(MyResourceSerializer)
    allow_output_serializer(MyResourceSerializer)
    freeze_io!

    def action
      data = deserialize!(request)
      render_media(data, status: 201)
    end
  end

  def setup
    @controller = FakeStrictController.new
    @response = ActionDispatch::Response.new
  end

  def test_input_validates
    content_type = 'application/vnd.mydomain.my_resource.v1+json'
    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => StringIO.new({ test: 1, _links: { example: { href: "https://example.org/" } } }.to_json),
      'CONTENT_TYPE' => content_type,
      'HTTP_ACCEPT' => "#{content_type}, application/problem+json; q=0.1"
    })

    # Passing input to output should fail (output isn't loose)
    assert_raises MediaTypes::Serialization::OutputValidationFailedError do
      @controller.dispatch(:action, request, @response)
    end
  end
end

