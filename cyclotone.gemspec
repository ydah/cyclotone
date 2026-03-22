# frozen_string_literal: true

require_relative "lib/cyclotone/version"

Gem::Specification.new do |spec|
  spec.name = "cyclotone"
  spec.version = Cyclotone::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Pattern-based live coding primitives for Ruby."
  spec.description = "Cyclotone provides rational-time spans, immutable pattern events, and composable pattern primitives for building live coding music tools in Ruby."
  spec.homepage = "https://github.com/ydah/cyclotone"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir.glob(%w[lib/**/* exe/* README* LICENSE* Rakefile *.gemspec], File::FNM_DOTMATCH).select do |path|
      File.file?(path)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_development_dependency "rspec", "~> 3.13"
end
