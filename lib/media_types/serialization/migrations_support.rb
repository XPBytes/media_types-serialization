# frozen_string_literal: true

require 'active_support/concern'
require 'media_types/serialization/migrations_command'

module MediaTypes
  module Serialization
    module MigrationsSupport
      extend ActiveSupport::Concern

      included do
        # This is the same as doing matrr_accessor but have it isolated to the class. Subclass changes to change these
        # values, but this allows for definition as a concern.

        class << self
          attr_accessor :migrations
        end

        delegate :migrations,
                 :migrations=,
                 to: :class
      end

      class_methods do
        def migrator(serializer)
          return nil unless migrations
          migrations.call(serializer)
        end

        protected

        def backward_migrations(&block)
          self.migrations = lambda do |serializer|
            MigrationsCommand.new(serializer).tap do |callable|
              callable.instance_exec(&block)
            end
          end
        end
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
