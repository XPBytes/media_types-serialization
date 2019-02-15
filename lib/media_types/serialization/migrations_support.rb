# frozen_string_literal: true

require 'active_support/concern'
require 'media_types/serialization/migrations_command'

module MediaTypes
  module Serialization
    module MigrationsSupport
      extend ActiveSupport::Concern

      class_methods do
        def migrator(serializer)
          return nil unless migrations_
          migrations_.call(serializer)
        end

        protected

        def backward_migrations(&block)
          self.migrations_ = lambda do |serializer|
            migrations = MigrationsCommand.new(serializer)
            migrations.instance_exec(&block)

            return migrations
          end
        end

        private

        attr_accessor :migrations_
      end

      def migrate(result = nil, media_type = current_media_type, view = current_view)
        result ||= yield

        migrator = self.class.migrator(self)
        return result unless migrator
        migrator.call(result, media_type, view)
      end
    end
  end
end
