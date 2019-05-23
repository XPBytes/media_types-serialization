# frozen_string_literal: true

require 'delegate'

require 'action_controller'

module MediaTypes
  module Serialization
    module Wrapper
      class HtmlWrapper < SimpleDelegator

        delegate :to_s, to: :to_html
        delegate :class, to: :__getobj__

        def initialize(serializer, view: nil, **render_options)
          __setobj__ serializer

          self.view = view
          self.render_options = render_options
        end

        def to_html
          return super if __getobj__.respond_to?(:to_html)
          to_api_viewer(layout: ::MediaTypes::Serialization.html_wrapper_layout)
        end

        def to_api_viewer(content_type: nil, layout: ::MediaTypes::Serialization.api_viewer_layout)
          ActionController::Base.render(
            layout || 'serializers/wrapper/html_wrapper',
            assigns: {
              serializer: self,
              view: view,
              content_type: content_type,
              **render_options
            }
          )
        end

        private

        attr_accessor :view, :render_options
      end
    end
  end
end
