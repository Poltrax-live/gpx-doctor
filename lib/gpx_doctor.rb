# frozen_string_literal: true

require 'gpx_doctor/version'
require 'gpx_doctor/configuration'
require 'gpx_doctor/models/email'
require 'gpx_doctor/models/link'
require 'gpx_doctor/models/copyright'
require 'gpx_doctor/models/person'
require 'gpx_doctor/models/bounds'
require 'gpx_doctor/models/waypoint'
require 'gpx_doctor/models/metadata'
require 'gpx_doctor/models/track_segment'
require 'gpx_doctor/models/route'
require 'gpx_doctor/models/track'
require 'gpx_doctor/elevation_client'
require 'gpx_doctor/statistics_enhancer'
require 'gpx_doctor/parser'

module GpxDoctor
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
