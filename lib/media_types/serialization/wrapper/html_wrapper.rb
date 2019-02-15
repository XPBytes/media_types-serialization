# frozen_string_literal: true

require 'delegate'

require 'action_controller'

require 'media_types/serialization/base'
require 'media_types/serialization/wrapper/root_key'

module MediaTypes
  module Serialization
    module Wrapper
      class HtmlWrapper < DelegateClass(Base)

        delegate :to_s, to: :to_html
        delegate :class, to: :__getobj__

        def initialize(serializer, view: nil, **render_options)
          super serializer
          self.view = view
          self.render_options = render_options
        end

        def to_html
          return super if __getobj__.respond_to?(:to_html)
          ActionController::Base.render(
            'serializers/wrapper/html_wrapper',
            assigns: {
              serializer: self,
              view: view,
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
