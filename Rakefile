# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

desc "Generate YARD documentation"
YARD::Rake::YardocTask.new(:yard)

task default: :spec
