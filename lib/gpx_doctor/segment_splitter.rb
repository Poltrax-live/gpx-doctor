# frozen_string_literal: true

module GpxDoctor
  class SegmentSplitter
    # Splits a sequence of waypoints so that no two consecutive points are
    # farther apart than +max_distance+ meters.  Pairs that are already within
    # the limit are left untouched.  When a pair exceeds the limit, evenly
    # spaced intermediate points are interpolated between them (lat/lon always;
    # ele and time only when both endpoints have values).
    #
    # Returns a new array; the original is not mutated.
    def split(points, max_distance)
      return points if points.nil? || points.size < 2

      result = [points.first]

      points.each_cons(2) do |current, nxt|
        dist = DistanceCalculator.distance(current, nxt)

        if dist > max_distance
          n_segments = (dist / max_distance).ceil
          (1...n_segments).each do |i|
            fraction = i.to_f / n_segments
            result << interpolate(current, nxt, fraction)
          end
        end

        result << nxt
      end

      result
    end

    private

    def interpolate(a, b, fraction)
      ele  = a.ele  && b.ele  ? a.ele  + fraction * (b.ele  - a.ele)  : nil
      time = a.time && b.time ? a.time + fraction * (b.time - a.time) : nil

      Models::Waypoint.new(
        lat:  a.lat + fraction * (b.lat - a.lat),
        lon:  a.lon + fraction * (b.lon - a.lon),
        ele:  ele,
        time: time
      )
    end
  end
end
