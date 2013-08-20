require 'rails/generators'
require 'rails/generators/migration'

module Historyable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      # Implement the required interface for Rails::Generators::Migration.
      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        else
         "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      def create_migration_file
        migration_template 'migration.rb', 'db/migrate/create_changes.rb'
      end
    end
  end
end
