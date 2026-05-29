raise "appClean must only run in test environment (currently: #{Rails.env})" unless Rails.env.test?

DatabaseCleaner.strategy = :truncation
DatabaseCleaner.clean

CypressOnRails::SmartFactoryWrapper.reload
