
require 'simplecov'
begin
  require 'codeclimate-test-reporter'
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    CodeClimate::TestReporter::Formatter
  ]
rescue LoadError
  SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter]
end
SimpleCov.start

RSpec.configure do |config|
  # Defaults from "rspec --init" for compatibility with RSpec version 4
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
