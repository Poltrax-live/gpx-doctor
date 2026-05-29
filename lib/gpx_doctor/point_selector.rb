# frozen_string_literal: true

module GpxDoctor
  class PointSelector
    # Returns the total distance in meters for a sequence of +points+.
    def total_distance(points)
      return 0.0 if points.nil? || points.size < 2

      total = 0.0
      points.each_cons(2) { |a, b| total += DistanceCalculator.distance(a, b) }
      total
    end

    # Selects up to +max_points+ points from +points+ with equal distance spread.
    # Always includes the first and last points. Returns a new array; the original
    # is not mutated. When +points+ already has fewer or equal elements than
    # +max_points+, it is returned unchanged.
    def select(points, max_points)
      return points if points.nil? || max_points <= 0 || points.size <= max_points

      m = points.size
      n = max_points

      # For n == 1 there is no denominator (n - 1 = 0), so just keep the first point.
      return [points[0]] if n == 1

      cumulative = [0.0]
      points.each_cons(2) do |a, b|
        cumulative << cumulative.last + DistanceCalculator.distance(a, b)
      end
      total = cumulative.last

      # Degenerate case: all points are at the same location — fall back to index spread.
      if total.zero?
        indices = (0...n).map { |i| (i * (m - 1).to_f / (n - 1)).round }
        return indices.uniq.map { |idx| points[idx] }
      end

      used = {}
      selected_indices = (0...n).map do |i|
        target = i * total / (n - 1).to_f
        # Find the closest unused point to the target cumulative distance.
        best_idx = cumulative
          .each_with_index
          .reject { |_, idx| used[idx] }
          .min_by { |d, _| (d - target).abs }
          .last
        used[best_idx] = true
        best_idx
      end

      selected_indices.sort.map { |idx| points[idx] }
    end
  end
end
