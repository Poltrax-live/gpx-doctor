# frozen_string_literal: true

module GpxDoctor
  # Tells how much of a track follows an already known path.
  #
  #   GpxDoctor::Similarity.compare_files('planned.gpx', 'ridden.gpx') # => 0.94
  #
  # Every point of the compared data is measured against the reference path —
  # against its points *and* against the stretches between them — and the result
  # is the fraction of compared points lying within +tolerance+ metres of it:
  # 0.0 when none of them follow the path, 1.0 when all of them do. Comparing a
  # file with itself therefore returns 1.0.
  #
  # Standalone <wpt> elements are points of interest rather than part of a path,
  # so they are ignored on both sides unless a file holds nothing else.
  class Similarity
    # How far, in metres, a point may sit from the reference path and still
    # count as following it.
    DEFAULT_TOLERANCE = 25.0
    ROUND_DIGITS = 4
    # Guards sample_interval against runaway interpolation over a huge gap.
    MAX_SAMPLES_PER_PAIR = 10_000

    class << self
      # Compares two GPX files.
      #
      #   GpxDoctor::Similarity.compare_files('original.gpx', 'compared.gpx')
      def compare_files(original_file, compared_file, tolerance: DEFAULT_TOLERANCE, sample_interval: nil)
        run(
          PointExtractor.collections(original_file),
          PointExtractor.collections(compared_file),
          tolerance: tolerance,
          sample_interval: sample_interval
        )
      end

      # Compares a reference path with any supported data: a GPX file path, GPX
      # XML, a GpxDoctor::Parser::Result, a route/track/segment, a WKT geometry
      # or an array of coordinates (waypoints, [lat, lon] pairs, hashes with
      # lat/lon, latitude/longitude or x/y keys, PostGIS points, …).
      #
      #   GpxDoctor::Similarity.compare('original.gpx', [{ lat: 48.21, lon: 16.36 }, …])
      #
      # +coordinate_order+ applies to bare numeric pairs only: pass
      # <tt>:lon_lat</tt> for PostGIS/GeoJSON style [lon, lat] coordinates.
      def compare(original, compared, tolerance: DEFAULT_TOLERANCE, sample_interval: nil, coordinate_order: :lat_lon)
        run(
          PointExtractor.collections(original, coordinate_order: coordinate_order),
          PointExtractor.collections(compared, coordinate_order: coordinate_order),
          tolerance: tolerance,
          sample_interval: sample_interval
        )
      end

      # Compares a reference path with a GeoJSON document (a Hash, a JSON string
      # or a path to a JSON file). Positions are read as [lon, lat] per RFC 7946.
      #
      #   GpxDoctor::Similarity.geojson_compare('original.gpx', geojson)
      def geojson_compare(original, geojson, tolerance: DEFAULT_TOLERANCE, sample_interval: nil)
        run(
          PointExtractor.collections(original),
          PointExtractor.geojson_collections(geojson),
          tolerance: tolerance,
          sample_interval: sample_interval
        )
      end

      private

      def run(original_collections, compared_collections, tolerance:, sample_interval:)
        new(
          original_collections,
          compared_collections,
          tolerance: tolerance,
          sample_interval: sample_interval
        ).compare
      end
    end

    # +original_collections+ and +compared_collections+ are arrays of point
    # sequences of [lat, lon] pairs, as returned by PointExtractor.
    def initialize(original_collections, compared_collections, tolerance: DEFAULT_TOLERANCE, sample_interval: nil)
      @original_collections = original_collections
      @compared_collections = compared_collections
      @tolerance = positive_float(tolerance, 'tolerance')
      @sample_interval = sample_interval.nil? ? nil : positive_float(sample_interval, 'sample_interval')
      validate_collections!
    end

    # Fraction of the compared points lying on the reference path, 0.0 to 1.0.
    def compare
      index = PathIndex.new(@original_collections, @tolerance)
      total = 0
      close = 0

      each_compared_position do |lat, lon|
        total += 1
        close += 1 if index.close?(lat, lon)
      end

      (close.to_f / total).round(ROUND_DIGITS)
    end

    private

    def validate_collections!
      raise ArgumentError, 'the original path holds no points' if no_points?(@original_collections)
      raise ArgumentError, 'there are no points to compare' if no_points?(@compared_collections)
    end

    def no_points?(collections)
      collections.all?(&:empty?)
    end

    def each_compared_position(&block)
      @compared_collections.each do |points|
        next if points.empty?

        first = points.first
        yield(first[0], first[1])

        points.each_cons(2) do |a, b|
          sample_between(a, b, &block) if @sample_interval
          yield(b[0], b[1])
        end
      end
    end

    # Extra positions along the straight line between two compared points, so
    # that a sparse track is judged by the path it describes rather than by its
    # few vertices.
    def sample_between(a, b)
      distance = Geo.distance(a, b)
      return if distance <= @sample_interval

      steps = [(distance / @sample_interval).ceil, MAX_SAMPLES_PER_PAIR].min
      (1...steps).each do |step|
        lat, lon = Geo.interpolate(a, b, step.to_f / steps)
        yield(lat, lon)
      end
    end

    def positive_float(value, name)
      number =
        begin
          Float(value)
        rescue ArgumentError, TypeError
          raise ArgumentError, "#{name} must be a number, got #{value.inspect}"
        end
      raise ArgumentError, "#{name} must be positive, got #{value.inspect}" unless number.positive?

      number
    end
  end
end
