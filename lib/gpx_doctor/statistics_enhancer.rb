# frozen_string_literal: true

module GpxDoctor
  class StatisticsEnhancer
    # Approximate degrees-to-meters conversion factors.
    # 1 degree latitude  ≈ 111_320 m
    # 1 degree longitude ≈ 111_320 m * cos(latitude)
    METERS_PER_DEGREE_LAT = 111_320.0

    # Enhances each consecutive pair of waypoints with statistics:
    #   - distance_to_next  (meters, flat-earth Pythagorean approximation)
    #   - elevation_change   (meters, next.ele - current.ele; nil when elevation missing)
    #   - direction          (degrees 0-360, geographic bearing to next point)
    #
    # The last point in the list receives nil for all three fields.
    # Mutates waypoints in place.
    def enhance(waypoints)
      return if waypoints.nil? || waypoints.size < 2

      waypoints.each_cons(2) do |current, nxt|
        dlat_m = (nxt.lat - current.lat) * METERS_PER_DEGREE_LAT
        avg_lat_rad = (current.lat + nxt.lat) / 2.0 * Math::PI / 180.0
        dlon_m = (nxt.lon - current.lon) * METERS_PER_DEGREE_LAT * Math.cos(avg_lat_rad)

        current.distance_to_next = Math.sqrt(dlat_m**2 + dlon_m**2)

        current.elevation_change = if current.ele && nxt.ele
                                     nxt.ele - current.ele
                                   end

        current.direction = bearing(dlat_m, dlon_m)
      end
    end

    private

    # Returns geographic bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West).
    def bearing(dlat_m, dlon_m)
      angle_rad = Math.atan2(dlon_m, dlat_m)
      degrees = angle_rad * 180.0 / Math::PI
      degrees % 360
    end
  end
end
