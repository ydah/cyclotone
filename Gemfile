# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in cyclotone.gemspec
gemspec

ruby_version = Gem::Version.new(RUBY_VERSION)

gem "irb"
gem "rake", "~> 13.0"
gem "rbs", "~> 4.0", require: false if ruby_version >= Gem::Version.new("3.2")
gem "rspec", "~> 3.13"
gem "rubocop", "~> 1.86", require: false
gem "rubocop-rake", "~> 0.7", require: false
gem "simplecov", "~> 0.22"
gem "yard", "~> 0.9"

gem "prop_check", "~> 1.0", group: :development, require: false

gem "mutant-rspec", "~> 0.16.3", group: :development, require: false if ruby_version >= Gem::Version.new("3.3")
