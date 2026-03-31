# frozen_string_literal: true

require "bundler/setup"
require "gpx_doctor"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after do
    GpxDoctor.reset_configuration!
  end
end
