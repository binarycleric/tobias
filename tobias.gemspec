# frozen_string_literal: true

require_relative "lib/tobias/version"

Gem::Specification.new do |s|
  s.name        = "tobias"
  s.version     = Tobias::VERSION
  s.licenses    = ["MIT"]
  s.summary     = Tobias::SUMMARY
  s.description = Tobias::DESCRIPTION
  s.authors     = ["Jon Daniel"]
  s.email       = "binarycleric@gmail.com"
  s.homepage    = "https://github.com/binarycleric/tobias"
  s.metadata    = { "source_code_uri" => "https://github.com/binarycleric/tobias",
                    "rubygems_mfa_required" => "true" }

  s.files = Dir.glob("lib/**/*", File::FNM_DOTMATCH)
  s.require_paths = %w[lib]

  s.bindir = "bin"
  s.executables = ["tobias"]

  s.required_ruby_version = ">= 3.3.0"

  s.add_dependency "activesupport", "~> 8.0", ">= 8.0.0"
  s.add_dependency "benchmark", "~> 0.4", ">= 0.4.0"
  s.add_dependency "bundler", "~> 2.4", ">= 2.4.0"
  s.add_dependency "concurrent-ruby", "~> 1.3", ">= 1.3.0"
  s.add_dependency "dry-configurable", "~> 1.0", ">= 1.0.0"
  s.add_dependency "enumerable-stats", "~> 1.1", ">= 1.1.0"
  s.add_dependency "json", "~> 2.13", ">= 2.13.0"
  s.add_dependency "pg", "~> 1.6", ">= 1.6.0"
  s.add_dependency "sequel", "~> 5.76", ">= 5.76.0"
  s.add_dependency "thor", "~> 1.3", ">= 1.3.0"
  s.add_dependency "tty-markdown", "~> 0.7", ">= 0.7.0"
  s.add_dependency "tty-table", "~> 0.12", ">= 0.12.0"
end
