# frozen_string_literal: true

module GpxDoctor
  class StatisticsEnhancer
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
        current.distance_to_next = DistanceCalculator.distance(current, nxt)

        current.elevation_change = if current.ele && nxt.ele
                                     nxt.ele - current.ele
                                   end

        current.direction = DistanceCalculator.bearing(current, nxt)
      end
    end
  end
end
