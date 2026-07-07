# frozen_string_literal: true

module GpxDoctor
  class CumulativeDistanceEnhancer
    # Enhances each waypoint with cumulative distance from the start of the segment/route.
    # The first point receives cumulative_distance = 0.0
    # Each subsequent point receives cumulative_distance = previous.cumulative_distance + distance from previous
    # Distance is stored in kilometers for metric and miles for imperial.
    #
    # Mutates waypoints in place.
    def enhance(waypoints)
      return if waypoints.nil? || waypoints.empty?

      unit_system = GpxDoctor.configuration.unit_system

      cumulative = 0.0
      waypoints.first.cumulative_distance = cumulative

      waypoints.each_cons(2) do |current, nxt|
        distance_meters = DistanceCalculator.distance(current, nxt)
        distance_km = distance_meters / 1000.0
        distance_converted = UnitConverter.convert_cumulative_distance(distance_km, unit_system)
        cumulative += distance_converted
        nxt.cumulative_distance = cumulative
      end
    end
  end
end
