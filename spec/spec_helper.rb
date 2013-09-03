require 'bundler/setup'
require 'rspec'
require 'sqlite3'
require 'database_cleaner'

require 'historyable'

Dir[File.expand_path('../../spec/support/*.rb', __FILE__)].map(&method(:require))
Dir[File.expand_path('../../spec/support/macros/*.rb', __FILE__)].map(&method(:require))

RSpec.configure do |config|

  config.include DatabaseMacros

  config.before(:suite) do
    Database.setup
    Database.run_default_migration

    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
