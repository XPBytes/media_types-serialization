# frozen_string_literal: true
#
module MediaTypes
  module Serialization
    class MigrationsCommand
      def initialize(serializer)
        self.serializer = serializer
        self.migrations = {}
      end

      def call(result, mime_type, view)
        return result if mime_type.is_a?(String) || matches_current_mime_type?(view: view, mime_type: mime_type)

        migrations.reduce(result) do |migrated, (version, migration)|
          migrated = migration.call(migrated)
          next migrated unless matches_mime_type?(mime_type.version(version), mime_type)
          break migrated
        end
      end

      private

      attr_accessor :serializer, :migrations

      def version(version, &block)
        migrations[version] = ->(result) { serializer.instance_exec(result, &block) }
      end

      def matches_current_mime_type?(view:, mime_type:)
        serializer.class.current_mime_type(view: view) == mime_type.to_s
      end

      def matches_mime_type?(left, right)
        left.to_s == right.to_s
      end
    end
  end
end
