# frozen_string_literal: true

require_relative "lib/gpx_doctor/version"

Gem::Specification.new do |spec|
  spec.name          = "gpx_doctor"
  spec.version       = GpxDoctor::VERSION
  spec.authors       = ["Poltrax"]
  spec.summary       = "Parse and manipulate GPX routes"
  spec.description   = "GPX Doctor helps with manipulation of GPX routes. It parses GPX 1.1 files into Ruby objects."
  spec.homepage      = "https://github.com/Poltrax-live/gpx-doctor"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]

  spec.add_dependency "nokogiri", "~> 1.15"

  spec.add_development_dependency "rspec", "~> 3.12"
end
