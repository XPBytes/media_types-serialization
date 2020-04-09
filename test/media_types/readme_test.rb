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

class MediaTypes::ReadmeTest < Minitest::Test
  class BookValidator
    include ::MediaTypes::Dsl

    def self.organisation
      'acme'
    end

    use_name 'book'

    validations do
      version 1 do
        attribute :book do
          attribute :title, String
        end
      end

      version 2 do
        attribute :book do
          attribute :title, String
          attribute :description, String
        end
      end

      version 3 do
        attribute :book do
          link :self

          attribute :title, String
          attribute :description, String
        end

        view :index do
          attribute :books do
            link :self

            collection :_index, allow_empty: true do
              not_strict
            end
          end
        end

        view :collection do
          attribute :books do
            link :self

            collection :_embedded, allow_empty: true do
              attribute :book do
                link :self
                attribute :title, String
                attribute :description, String
              end
            end
              
          end
        end
      end
    end
  end

  class BookSerializer < ::MediaTypes::Serialization::Base
    validator BookValidator

    output version: 1 do |obj, version, context|
      raise 'bad input' unless obj.is_a? Book
      {
        book: {
          title: obj.title
        }
      }
    end

    output versions: [2, 3] do  |obj, version, context|
      raise 'bad input' unless obj.is_a? Book
      attribute :book do
        link :self, href: 'https://example.org' if version >= 3

        attribute :title, obj.title
        attribute :description, obj.description if version >= 2
      end
    end

    output view: :index, version: 3 do |arr, version, context|
      raise 'bad input' unless arr.is_a? Array
      attribute :books do
        link :self, href: 'https://example.org/1'

        index arr, version: version
      end
    end

    output view: :collection, version: 3 do |arr, version, context|
      attribute :books do
        link :self, href: 'https://example.org/2'

        collection arr, version: version
      end
    end
  end

  class Book
    attr_accessor :title, :description
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
    allow_output_serializer BookSerializer, only: %i[show]
    allow_output_serializer BookSerializer, view: :index, only: %i[index]
    allow_output_serializer BookSerializer, view: :collection, only: %i[index]
    freeze_io!

    def show
      book = Book.new
      book.title = 'Everything, abridged'
      book.description = 'Mu'

      render_media book
    end
    
    def index
      book = Book.new
      book.title = 'Everything, abridged'
      book.description = 'Mu'

      render_media [book]
    end
  end

  def setup
    @controller = FakeController.new
    @response = ActionDispatch::Response.new
  end

  def test_creating_a_serializer_paragraph
    content_type = BookValidator.version(1).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "book" => { "title" => "Everything, abridged" } }, result)
  end

  def test_versioning_paragraph
    content_type = BookValidator.version(2).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "book" => { "title" => "Everything, abridged", "description" => "Mu" } }, result)
  end

  def test_links_paragraph
    content_type = BookValidator.version(3).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:show, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "book" => { "_links" => { "self" => { "href" => "https://example.org" } }, "title" => "Everything, abridged", "description" => "Mu" } }, result)
  end
  
  def test_index_paragraph
    content_type = BookValidator.view(:index).version(3).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:index, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    assert_equal( { "books" => { "_links" => { "self" => { "href" => "https://example.org/1" } }, "_index" => [{ "href" => "https://example.org" }] } }, result)
  end
  
  def test_collection_paragraph
    content_type = BookValidator.view(:collection).version(3).identifier

    request = ActionDispatch::Request.new({
      Rack::RACK_INPUT => '',
      'HTTP_ACCEPT' => "#{content_type}, text/html; q=0.1"
    })

    @controller.dispatch(:index, request, @response)
    assert_equal content_type, @response.content_type.split(';').first

    result = Oj.load(@response.body)
    book = { "book" => { "_links" => { "self" => { "href" => "https://example.org" } }, "title" => "Everything, abridged", "description" => "Mu" } }
    assert_equal( { "books" => { "_links" => { "self" => { "href" => "https://example.org/2" } }, "_embedded" => [book] } }, result)
  end
end

