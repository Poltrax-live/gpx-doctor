# frozen_string_literal: true

module GpxDoctor
  # Grafts a "transplant" GPX route onto an original GPX route: it finds where
  # the transplant's start and end sit closest to the original route, and
  # replaces everything between those two points (inclusive) with the
  # transplant.
  #
  #   # original: n1, n2, ..., n9 — m1 sits close to n2, m3 close to n8
  #   result = GpxDoctor::Transplant.graft('original.gpx', 'transplant.gpx')
  #   result.points # => [n1, m1, m2, m3, n9]
  #
  # Accepts anything {Parser} does: a file path, GPX XML, or an already
  # parsed {Parser::Result}. Returns a new {Parser::Result} — the original
  # objects passed in are never mutated.
  #
  # Works on the single route or track segment that best matches the
  # transplant; a GPX file with several populated routes/segments is
  # supported as long as the transplant only attaches to one of them. See
  # {Transplant::Coordinates} for plain arrays of points and
  # {Transplant::GeoJson} for GeoJSON documents.
  class Transplant
    # How far, in metres, the transplant's start and end may sit from the
    # original route and still be considered attached to it.
    DEFAULT_TOLERANCE = 25.0

    class << self
      # Grafts +transplant+ onto +original+.
      #
      # +tolerance+ is the furthest, in metres, the transplant's start and end
      # may sit from the original route; pass +nil+ to always graft onto the
      # nearest points regardless of distance.
      def graft(original, transplant, tolerance: DEFAULT_TOLERANCE)
        new(original, transplant, tolerance: tolerance).graft
      end
    end

    def initialize(original, transplant, tolerance: DEFAULT_TOLERANCE)
      @original = resolve(original)
      @transplant = resolve(transplant)
      @tolerance = tolerance
    end

    def graft
      collections = path_collections(@original)
      raise ArgumentError, 'the original GPX holds no route or track points' if collections.empty?

      replacement = point_pairs(@transplant.points)
      raise ArgumentError, 'the transplant GPX holds no route or track points' if replacement.empty?

      target, points = locate_target(collections, replacement)
      spliced = Matcher.splice(points, replacement, tolerance: @tolerance)
      rebuild(target, spliced)
    end

    private

    def resolve(source)
      return source if source.is_a?(Parser::Result)

      source = source.to_path if source.respond_to?(:to_path)
      raise ArgumentError, "unsupported GPX source: #{source.class}" unless source.is_a?(String)

      gpx_file?(source) ? Parser.parse(source) : Parser.parse_string(source)
    end

    def gpx_file?(value)
      return false if value.length > 4096 || value.match?(/[\n\0]/)

      File.file?(value)
    end

    # One entry per non-empty route and per non-empty track segment, in the
    # same order as Parser::Result#points.
    def path_collections(result)
      collections = result.routes.each_with_index.map do |route, index|
        { kind: :route, index: index, points: route.points }
      end

      result.tracks.each_with_index do |track, track_index|
        track.segments.each_with_index do |segment, segment_index|
          collections << { kind: :track_segment, track_index: track_index, segment_index: segment_index, points: segment.points }
        end
      end

      collections.reject { |collection| collection[:points].empty? }
    end

    def point_pairs(points)
      points.map { |point| [point, [point.lat, point.lon]] }
    end

    # The single collection whose closest points to the transplant's start and
    # end are, combined, the closest of all collections.
    def locate_target(collections, replacement)
      start_position = replacement.first[1]
      end_position = replacement.last[1]

      scored = collections.map do |collection|
        pairs = point_pairs(collection[:points])
        _, start_distance = Matcher.nearest(pairs, start_position)
        _, end_distance = Matcher.nearest(pairs, end_position)
        [collection, pairs, start_distance + end_distance]
      end

      target, pairs, = scored.min_by { |(_collection, _pairs, score)| score }
      [target, pairs]
    end

    def rebuild(target, spliced_points)
      result = @original.dup

      case target[:kind]
      when :route
        result.routes = result.routes.each_with_index.map do |route, index|
          index == target[:index] ? with_attribute(route, :points, spliced_points) : route
        end
      when :track_segment
        result.tracks = result.tracks.each_with_index.map do |track, track_index|
          next track unless track_index == target[:track_index]

          segments = track.segments.each_with_index.map do |segment, segment_index|
            segment_index == target[:segment_index] ? with_attribute(segment, :points, spliced_points) : segment
          end
          with_attribute(track, :segments, segments)
        end
      end

      result
    end

    def with_attribute(struct, attribute, value)
      copy = struct.dup
      copy.public_send(:"#{attribute}=", value)
      copy
    end
  end
end
