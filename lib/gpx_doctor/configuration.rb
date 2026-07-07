# frozen_string_literal: true

module GpxDoctor
  class Configuration
    attr_accessor :elevation_server,
                  :elevation_server_url,
                  :elevation_server_user,
                  :elevation_server_password,
                  :unit_system

    def initialize
      @elevation_server          = false
      @elevation_server_url      = nil
      @elevation_server_user     = nil
      @elevation_server_password = nil
      @unit_system               = :metric
    end

    def unit_system=(value)
      unless [:metric, :imperial].include?(value)
        raise ArgumentError, "unit_system must be :metric or :imperial"
      end
      @unit_system = value
    end
  end
end
