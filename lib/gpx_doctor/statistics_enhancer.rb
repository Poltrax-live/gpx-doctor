# frozen_string_literal: true

module GpxDoctor
  class StatisticsEnhancer
    # Enhances each consecutive pair of waypoints with statistics:
    #   - distance_to_next  (meters or feet depending on configuration)
    #   - elevation_change  (meters or feet depending on configuration)
    #   - direction         (degrees 0-360, geographic bearing to next point)
    #
    # The last point in the list receives nil for all three fields.
    # Mutates waypoints in place.
    def enhance(waypoints)
      return if waypoints.nil? || waypoints.size < 2

      unit_system = GpxDoctor.configuration.unit_system

      waypoints.each_cons(2) do |current, nxt|
        distance_meters = DistanceCalculator.distance(current, nxt)
        current.distance_to_next = UnitConverter.convert_distance(distance_meters, unit_system)

        current.elevation_change = if current.ele && nxt.ele
                                     elevation_change_meters = nxt.ele - current.ele
                                     UnitConverter.convert_elevation(elevation_change_meters, unit_system)
                                   end

        current.direction = DistanceCalculator.bearing(current, nxt)
      end
    end
  end
end
