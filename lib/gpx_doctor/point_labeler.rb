# frozen_string_literal: true

module GpxDoctor
  class PointLabeler
    # Tolerance (in the configured distance unit) used to decide whether a
    # label distance coincides with an existing point, to avoid inserting a
    # near-duplicate point right next to it.
    EPSILON = 1e-9

    # Inserts an interpolated point at every multiple of +label_interval+
    # measured as cumulative distance from the start of +points+ (kilometres
    # for :metric, miles for :imperial — see GpxDoctor.configuration.unit_system).
    #
    # Existing points are left untouched. A new point is inserted between the
    # two existing points that bracket each label distance, with lat/lon
    # always interpolated, and ele/time interpolated only when both endpoints
    # have values. The new point's +label+ field is set to the target
    # distance (e.g. 1.0 for the point at the 1.0 km/mi mark).
    #
    # A label distance that falls (within a small tolerance) on an existing
    # point is skipped — no duplicate point is inserted.
    #
    # Returns a new array; the original is not mutated. When +points+ has
    # fewer than 2 elements, or +label_interval+ is nil, zero or negative,
    # the original array is returned unchanged.
    def label(points, label_interval)
      return points if points.nil? || points.size < 2 || label_interval.nil? || label_interval <= 0

      cumulative = cumulative_distances(points)

      result = [points.first]
      target = label_interval

      points.each_cons(2).with_index do |(a, b), i|
        start_dist = cumulative[i]
        end_dist = cumulative[i + 1]

        while target <= end_dist + EPSILON
          if target > start_dist + EPSILON && target < end_dist - EPSILON
            result << interpolate(a, b, start_dist, end_dist, target)
          end
          target += label_interval
        end

        result << b
      end

      result
    end

    private

    def cumulative_distances(points)
      unit_system = GpxDoctor.configuration.unit_system

      cumulative = [0.0]
      points.each_cons(2) do |a, b|
        distance_km = DistanceCalculator.distance(a, b) / 1000.0
        distance_converted = UnitConverter.convert_cumulative_distance(distance_km, unit_system)
        cumulative << cumulative.last + distance_converted
      end
      cumulative
    end

    def interpolate(a, b, start_dist, end_dist, target)
      fraction = (target - start_dist) / (end_dist - start_dist)
      ele  = a.ele  && b.ele  ? a.ele  + fraction * (b.ele  - a.ele)  : nil
      time = a.time && b.time ? a.time + fraction * (b.time - a.time) : nil

      Models::Waypoint.new(
        lat:   a.lat + fraction * (b.lat - a.lat),
        lon:   a.lon + fraction * (b.lon - a.lon),
        ele:   ele,
        time:  time,
        label: target
      )
    end
  end
end
