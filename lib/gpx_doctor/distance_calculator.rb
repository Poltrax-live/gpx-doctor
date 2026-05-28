# frozen_string_literal: true

module GpxDoctor
  module DistanceCalculator
    # Approximate degrees-to-meters conversion factors.
    # 1 degree latitude  ≈ 111_320 m
    # 1 degree longitude ≈ 111_320 m * cos(latitude)
    METERS_PER_DEGREE_LAT = 111_320.0

    module_function

    # Returns the flat-earth Pythagorean distance in meters between two waypoints.
    def distance(a, b)
      dlat_m, dlon_m = components(a, b)
      Math.sqrt(dlat_m**2 + dlon_m**2)
    end

    # Returns geographic bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West)
    # between two waypoints.
    def bearing(a, b)
      dlat_m, dlon_m = components(a, b)
      angle_rad = Math.atan2(dlon_m, dlat_m)
      degrees = angle_rad * 180.0 / Math::PI
      degrees % 360
    end

    # Returns [dlat_m, dlon_m] — the north and east displacement in meters between a and b.
    def components(a, b)
      dlat_m = (b.lat - a.lat) * METERS_PER_DEGREE_LAT
      avg_lat_rad = (a.lat + b.lat) / 2.0 * Math::PI / 180.0
      dlon_m = (b.lon - a.lon) * METERS_PER_DEGREE_LAT * Math.cos(avg_lat_rad)
      [dlat_m, dlon_m]
    end
    module_function :components
    private_class_method :components
  end
end
