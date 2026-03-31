# frozen_string_literal: true

module GpxDoctor
  class Configuration
    attr_accessor :elevation_server,
                  :elevation_server_url,
                  :elevation_server_user,
                  :elevation_server_password,
                  :statistics

    def initialize
      @elevation_server          = false
      @elevation_server_url      = nil
      @elevation_server_user     = nil
      @elevation_server_password = nil
      @statistics                = false
    end
  end
end
