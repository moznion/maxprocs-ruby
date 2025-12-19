# frozen_string_literal: true

require_relative "lib/maxprocs/version"

Gem::Specification.new do |spec|
  spec.name = "maxprocs"
  spec.version = Maxprocs::VERSION
  spec.authors = ["moznion"]
  spec.email = ["moznion@mail.moznion.net"]

  spec.summary = "Detect CPU quota from Linux cgroups for container environments"
  spec.description = <<~DESC
    A lightweight Ruby gem that detects CPU quota from Linux cgroups (v1 and v2)
    and returns the appropriate number of processors for container environments.
    This is a Ruby equivalent of Go's uber-go/automaxprocs.
  DESC
  spec.homepage = "https://github.com/moznion/maxprocs-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "{sig}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rake", "~> 13.3"
  spec.add_development_dependency "standard", "~> 1.52"
  spec.add_development_dependency "rbs-inline", "~> 0.12"
  spec.add_development_dependency "steep", "~> 1.10"
end
