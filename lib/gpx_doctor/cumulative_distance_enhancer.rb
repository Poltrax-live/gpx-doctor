# frozen_string_literal: true

module GpxDoctor
  class CumulativeDistanceEnhancer
    # Enhances each waypoint with cumulative distance from the start of the segment/route.
    # The first point receives cumulative_distance = 0.0
    # Each subsequent point receives cumulative_distance = previous.cumulative_distance + distance from previous
    #
    # Mutates waypoints in place.
    def enhance(waypoints)
      return if waypoints.nil? || waypoints.empty?

      cumulative = 0.0
      waypoints.first.cumulative_distance = cumulative

      waypoints.each_cons(2) do |current, nxt|
        distance = DistanceCalculator.distance(current, nxt)
        cumulative += distance
        nxt.cumulative_distance = cumulative
      end
    end
  end
end
