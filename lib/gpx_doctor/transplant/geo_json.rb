# frozen_string_literal: true

module GpxDoctor
  class Transplant
    # Grafts a transplant onto a route described as GeoJSON (a Hash, a JSON
    # string, or a path to a JSON file).
    #
    #   GpxDoctor::Transplant::GeoJson.graft(route_geojson, transplant_geojson)
    #   # => { type: "Feature", properties: nil,
    #   #      geometry: { type: "LineString", coordinates: [...] } }
    #
    # Each document must describe exactly one line: a bare +LineString+
    # geometry, a +Feature+ wrapping one, or a +FeatureCollection+ holding
    # exactly one +LineString+ feature (other features, such as POI points,
    # are ignored). Positions are read and written as +[longitude, latitude]+
    # per RFC 7946, altitude included when present.
    class GeoJson
      class << self
        # +tolerance+ is the furthest, in metres, the transplant's start and
        # end may sit from the route; pass +nil+ to always graft onto the
        # nearest points regardless of distance.
        def graft(route, transplant, tolerance: Transplant::DEFAULT_TOLERANCE)
          new(route, transplant, tolerance: tolerance).graft
        end
      end

      def initialize(route, transplant, tolerance: Transplant::DEFAULT_TOLERANCE)
        @route = route
        @transplant = transplant
        @tolerance = tolerance
      end

      def graft
        route_line = line_of(@route, 'route')
        transplant_line = line_of(@transplant, 'transplant')

        spliced = Matcher.splice(pairs(route_line), pairs(transplant_line), tolerance: @tolerance)

        {
          type: 'Feature',
          properties: nil,
          geometry: {
            type: 'LineString',
            coordinates: spliced
          }
        }
      end

      private

      def pairs(coordinates)
        coordinates.map { |position| [position, Similarity::PointExtractor.geojson_position(position)] }
      end

      def line_of(source, label)
        coordinates = extract_line(load(source))
        raise ArgumentError, "the #{label} GeoJSON holds no positions" if coordinates.nil? || coordinates.empty?

        coordinates
      end

      def load(source)
        source = source.to_path if source.respond_to?(:to_path)

        case source
        when Hash
          source
        when String
          text = Similarity::PointExtractor.file?(source) ? File.read(source) : source
          Similarity::PointExtractor.parse_json(text)
        else
          raise ArgumentError, "unsupported GeoJSON source: #{source.class}"
        end
      end

      def extract_line(node)
        node = normalize(node)

        case node['type']
        when 'LineString'
          node['coordinates']
        when 'Feature'
          geometry = node['geometry']
          raise ArgumentError, 'expected a Feature with a LineString geometry' unless geometry

          extract_line(geometry)
        when 'FeatureCollection'
          line_from_features(node['features'])
        else
          raise ArgumentError, "expected a LineString, a Feature or a FeatureCollection, got #{node['type'].inspect}"
        end
      end

      def line_from_features(features)
        lines = Array(features).filter_map do |feature|
          geometry = normalize(feature)['geometry']
          geometry && normalize(geometry)['type'] == 'LineString' ? normalize(geometry)['coordinates'] : nil
        end

        raise ArgumentError, "expected exactly one LineString feature, found #{lines.size}" unless lines.size == 1

        lines.first
      end

      def normalize(node)
        raise ArgumentError, "unsupported GeoJSON node: #{node.inspect}" unless node.is_a?(Hash)

        Similarity::PointExtractor.normalize_keys(node)
      end
    end
  end
end
