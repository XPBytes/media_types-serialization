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

class MediaTypes::WildcardViewTest < Minitest::Test
  class ConfigurationValidator
    include MediaTypes::Dsl

    def self.organisation
      'delftsolutions'
    end

    use_name 'configuration'

    validations do
      version 1 do
        empty
      end

      view :test do
        version 1 do
          empty
        end
      end
    end
  end

  class ConfigurationSerializer < ::MediaTypes::Serialization::Base
    validator ConfigurationValidator

    # outputs with a Content-Type of application/vnd.soundersmusic.configuration.v1+json
    output version: 1 do |_, __, ___|
      {}
    end

    # outputs with a Content-Type of application/vnd.soundersmusic.configuration.legacy+json
    output view: :test, version: 1do |obj, _, __|
      {}
    end
  end

  def test_view_has_wildcards
    registrations = ConfigurationSerializer.outputs_for(views: [nil])
    assert registrations.registrations.has_key?('*/*'), 'Nil view does not have wildcard'

    registrations = ConfigurationSerializer.outputs_for(views: [:test])
    assert registrations.registrations.has_key?('*/*'), 'Test view does not have wildcard'
  end

end
