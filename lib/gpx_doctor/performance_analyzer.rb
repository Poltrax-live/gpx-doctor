# frozen_string_literal: true

module GpxDoctor
  class PerformanceAnalyzer
    def analyze(point_collections)
      raise InvalidGpxError, 'performance_analysis requires timestamps on path points' unless timestamps_present?(point_collections)

      analysis = time_metrics(point_collections)
      analysis.merge!(elevation_metrics(point_collections))
      analysis.merge!(vertical_speed_metrics(point_collections))
      analysis
    end

    private

    def timestamps_present?(point_collections)
      point_collections.flatten.any?(&:time)
    end

    def each_pair(point_collections)
      return enum_for(:each_pair, point_collections) unless block_given?

      point_collections.each do |points|
        points.each_cons(2) { |current, nxt| yield current, nxt }
      end
    end

    def time_metrics(point_collections)
      total_time_seconds = 0.0
      total_distance_km = 0.0
      speed_array = []

      each_pair(point_collections) do |current, nxt|
        next unless current.time && nxt.time

        delta_seconds = nxt.time - current.time
        next unless delta_seconds.positive?

        distance_km = DistanceCalculator.distance(current, nxt) / 1000.0
        speed_kmh = distance_km / (delta_seconds / 3600.0)

        total_time_seconds += delta_seconds
        total_distance_km += distance_km
        speed_array << round_three(speed_kmh)
      end

      avg_speed_kmh = if total_time_seconds.positive?
                        total_distance_km / (total_time_seconds / 3600.0)
                      else
                        0.0
                      end

      {
        total_time: total_time_seconds.round,
        distance: round_three(total_distance_km),
        avg_speed: round_three(avg_speed_kmh),
        top_speed: round_three(speed_array.max || 0.0),
        speed_array: speed_array
      }
    end

    def elevation_metrics(point_collections)
      elevation_change_array = each_pair(point_collections).filter_map do |current, nxt|
        next unless current.ele && nxt.ele

        round_three(nxt.ele - current.ele)
      end

      return {} if elevation_change_array.empty?

      ascent = elevation_change_array.select(&:positive?).sum.round
      descent = elevation_change_array.select(&:negative?).sum.abs.round

      {
        ascent: ascent,
        descent: descent,
        elevation_change_array: elevation_change_array
      }
    end

    def vertical_speed_metrics(point_collections)
      vertical_speed_array = each_pair(point_collections).filter_map do |current, nxt|
        next unless current.ele && nxt.ele && current.time && nxt.time

        delta_seconds = nxt.time - current.time
        next unless delta_seconds.positive?

        round_three((nxt.ele - current.ele) / delta_seconds)
      end

      return {} if vertical_speed_array.empty?

      {
        top_vertical_speed: round_three(vertical_speed_array.map(&:abs).max),
        vertical_speed_array: vertical_speed_array
      }
    end

    def round_three(value)
      value.round(3)
    end
  end
end
