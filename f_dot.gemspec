# frozen_string_literal: true

=begin

  f_dot.gemspec

  f_dot gem specification.

  by i2097i

=end

GEM_DESCRIPTION = "f_dot is checksum tool only a computer could love."

require_relative "lib/f_dot/version"

Gem::Specification.new do |spec|
  spec.name = "f_dot"
  spec.version = FDot::VERSION
  spec.authors = ["i2097i"]
  spec.email = ["i2097i@hotmail.com"]

  spec.description   = GEM_DESCRIPTION + "| v#{FDot::VERSION} | release notes: #{FDot::RELEASE_NOTES}"
  spec.summary       = GEM_DESCRIPTION
  spec.homepage      = "https://github.com/f-oss-om-foundation/f_dot"
  spec.license       = "MIT"
  spec.files         = `git ls-files`.split("\n").reject{|p| p.match?(/^(spec|.release|.*.gem$)/)}
  spec.bindir        = "bin"
  spec.executables   = ["f_dot"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.1"

  # development gems
  spec.add_development_dependency "bundler",              "~> 4.0", ">= 4.0.22"
  spec.add_development_dependency "listen",              "~> 3.10", ">= 3.10.1"
  spec.add_development_dependency "rake",              "~> 13.4", ">= 13.4.2"
  spec.add_development_dependency "rspec",              "~> 3.13", ">= 3.13.2"

  # runtime gems
  spec.add_runtime_dependency     "tty-prompt",              "~> 0.23", ">= 0.23.1"
  spec.add_runtime_dependency     "tty-font",              "~> 0.5", ">= 0.5.0"

end
