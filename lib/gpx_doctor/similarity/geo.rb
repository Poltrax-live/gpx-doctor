# frozen_string_literal: true

module GpxDoctor
  class Similarity
    # Flat-earth helpers working on plain +[latitude, longitude]+ pairs.
    #
    # They use the same approximation as {DistanceCalculator} (1 degree of
    # latitude is METERS_PER_DEGREE metres, longitude is scaled by the cosine of
    # the latitude), but without building Waypoint objects for the hundreds of
    # thousands of positions a comparison may touch.
    module Geo
      METERS_PER_DEGREE = DistanceCalculator::METERS_PER_DEGREE_LAT
      DEG_TO_RAD = Math::PI / 180.0

      module_function

      # Distance in metres between two [lat, lon] pairs.
      def distance(a, b)
        dlat_m = (b[0] - a[0]) * METERS_PER_DEGREE
        dlon_m = (b[1] - a[1]) * METERS_PER_DEGREE * Math.cos((a[0] + b[0]) / 2.0 * DEG_TO_RAD)
        Math.sqrt(dlat_m**2 + dlon_m**2)
      end

      # The [lat, lon] pair +fraction+ of the way from a to b.
      def interpolate(a, b, fraction)
        [a[0] + fraction * (b[0] - a[0]), a[1] + fraction * (b[1] - a[1])]
      end
    end
  end
end
