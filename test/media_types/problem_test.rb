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

require 'oj'

class MediaTypes::ProblemTest < Minitest::Test
  class BaseController < ActionController::Metal
    include AbstractController::Callbacks
    include AbstractController::Rendering
    include ActionController::MimeResponds
    include ActionController::Rendering
    include ActionController::Renderers
    include ActiveSupport::Rescuable

    include MediaTypes::Serialization
  end

  class FooError < ::StandardError
  end

  class FakeController < BaseController
    allow_output_docs "dummy resource"

    output_error FooError do |p, error|
      p.title "en-US", lang: 'en-US'
      p.title "nl-NL", lang: 'nl-NL'
      p.title "fr", lang: 'fr'

      p.status_code :forbidden
    end
    freeze_io!

    def error
      raise FooError, "test"
      render_media nil
    end

    def docs
      render_media nil
    end
  end

  def setup
    @controller = FakeController.new
    @response = ActionDispatch::Response.new
  end

  def test_error_output
    content_type = 'text/vnd.delftsolutions.docs'

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, application/problem+json, text/html; q=0.1",
      'HTTP_ACCEPT_LANGUAGE' => "nl"
    })

    begin
      @controller.dispatch(:error, request, @response)
    rescue FooError => e
      @controller.rescue_with_handler e
    end
    assert_equal 'application/problem+json', @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( 'nl-NL', result['title'] )
  end

  def test_docs_output
    content_type = '*/*'

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:docs, request, @response)
    assert_equal 'text/plain', @response.content_type.split(';').first
    assert_equal 'utf-8', @response.charset

    assert_equal( 'dummy resource', @response.body )
  end
end
