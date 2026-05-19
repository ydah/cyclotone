# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

desc "Run RuboCop"
task :rubocop do
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:rubocop_run)
  Rake::Task[:rubocop_run].invoke
rescue LoadError
  warn "rubocop is not available; run bundle install to enable linting"
end

desc "Syntax-check examples without external OSC/MIDI services"
task :examples do
  Dir.glob("examples/*.rb").each do |path|
    sh Gem.ruby, "-c", path
  end
end

desc "Generate YARD documentation"
YARD::Rake::YardocTask.new(:yard)

task default: %i[spec examples]
