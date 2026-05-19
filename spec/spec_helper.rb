# frozen_string_literal: true

SIMPLECOV_AVAILABLE = begin
  require "simplecov"
  true
rescue LoadError
  false
end unless defined?(SIMPLECOV_AVAILABLE)

if SIMPLECOV_AVAILABLE
  SimpleCov.start do
    enable_coverage :branch
    add_filter "/spec/"
    minimum_coverage line: 80, branch: 55
  end
end

require "cyclotone"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
