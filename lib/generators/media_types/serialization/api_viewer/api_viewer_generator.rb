require 'rails/generators/base'

module MediaTypes
  module Serialization
    class ApiViewerGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_controllers
        copy_file "template_controller.rb", "app/controllers/api/template_controller.rb"
      end

      def copy_views
        copy_file "api_viewer.html.erb", "app/views/serializers/wrapper/html_wrapper.html.erb"
      end

      def copy_initializer
        copy_file "initializer.rb", "config/initializers/media_types_serialization.rb"
      end

      def add_route
        route "namespace :api do\n  match '/template', controller: :template, action: :create, via: %i[get post], as: :template\nend\n\n"
      end
    end
  end
end
