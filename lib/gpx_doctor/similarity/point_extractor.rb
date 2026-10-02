# frozen_string_literal: true

require 'json'

module GpxDoctor
  class Similarity
    # Turns everything {Similarity} accepts — GPX files, parsed results, model
    # objects, coordinate arrays, hashes, PostGIS/WKT strings and GeoJSON — into
    # arrays of +[latitude, longitude]+ pairs.
    #
    # Pairs are grouped into collections (one per route, track segment, GeoJSON
    # geometry, WKT part …) so that no stretch of path is ever implied between
    # two unrelated point sequences.
    module PointExtractor
      COORDINATE_ORDERS = %i[lat_lon lon_lat].freeze
      LAT_KEYS = %w[lat latitude y].freeze
      LON_KEYS = %w[lon lng long longitude x].freeze
      GEOJSON_KEYS = %w[coordinates features geometry geometries].freeze
      WKT_TYPES = %w[POINT MULTIPOINT LINESTRING MULTILINESTRING POLYGON MULTIPOLYGON].freeze
      WKT_PATTERN = /\A\s*(?:SRID=\d+\s*;\s*)?(#{WKT_TYPES.join('|')})\s*(?:[ZM]{1,2}\s*)?\(/i
      FILE_EXTENSION_PATTERN = /\.(gpx|geojson|json|xml|wkt)\z/i
      # Longest string still worth handing to File.file?.
      MAX_PATH_LENGTH = 4096

      module_function

      # Positions of +source+, grouped into collections.
      #
      # +coordinate_order+ only applies to bare numeric pairs such as
      # [48.21, 16.36]; hashes, objects, WKT and GeoJSON carry their own order.
      def collections(source, coordinate_order: :lat_lon)
        unless COORDINATE_ORDERS.include?(coordinate_order)
          raise ArgumentError, "coordinate_order must be one of #{COORDINATE_ORDERS.inspect}"
        end

        source = source.to_path if source.respond_to?(:to_path)

        extract(source, coordinate_order).reject(&:empty?)
      end

      # Positions of a GeoJSON document (a Hash, a JSON string or a path to a
      # JSON file), grouped into collections. Per RFC 7946 every position is
      # read as [longitude, latitude].
      def geojson_collections(source)
        source = source.to_path if source.respond_to?(:to_path)

        data =
          case source
          when Hash, Array then source
          when String      then parse_json(file?(source) ? File.read(source) : source)
          else raise ArgumentError, "unsupported GeoJSON source: #{source.class}"
          end

        collections = []
        append_geojson(data, collections)
        collections = collections.reject(&:empty?)

        # Isolated points are points of interest, just like standalone <wpt>
        # elements, so they only count when the document describes no path.
        path = collections.reject { |positions| positions.size < 2 }
        path.empty? ? collections : path
      end

      def extract(source, order)
        case source
        when Parser::Result                      then result_collections(source)
        when Models::Track                       then source.segments.map { |seg| waypoint_positions(seg.points) }
        when Models::Route, Models::TrackSegment then [waypoint_positions(source.points)]
        when String                              then string_collections(source)
        when Hash                                then hash_collections(source)
        when Array                               then array_collections(source, order)
        else [[position(source, order)]]
        end
      end

      # The path of a parsed GPX file: routes first, then every track segment.
      # Standalone <wpt> elements are points of interest rather than part of the
      # path, so they are only used when the file holds nothing else.
      def result_collections(result)
        path = result.routes.map { |route| waypoint_positions(route.points) } +
               result.tracks.flat_map { |track| track.segments.map { |seg| waypoint_positions(seg.points) } }
        path = path.reject(&:empty?)
        return path unless path.empty?

        result.waypoints.map { |waypoint| [position(waypoint, :lat_lon)] }
      end

      def waypoint_positions(points)
        points.map { |point| coordinate_pair(point.lat, point.lon) }
      end

      def string_collections(value)
        return content_collections(File.read(value), value) if file?(value)
        raise ArgumentError, "file not found: #{value}" if value.match?(FILE_EXTENSION_PATTERN) && !value.match?(/[\n<{\[]/)

        content_collections(value, nil)
      end

      def content_collections(content, path)
        return result_collections(Parser.parse_string(content)) if xml?(content)
        return wkt_collections(content) if wkt?(content)
        return geojson_collections(content) if json?(content)

        raise ArgumentError,
              "unsupported source#{path ? " in #{path}" : ''}: expected GPX, GeoJSON, WKT or an array of coordinates"
      end

      def hash_collections(hash)
        normalized = normalize_keys(hash)
        return geojson_collections(hash) if normalized.key?('type') && GEOJSON_KEYS.any? { |key| normalized.key?(key) }

        [[position(hash, :lat_lon)]]
      end

      def array_collections(array, order)
        return [] if array.empty?
        return [[position(array, order)]] if array.size == 2 && numeric_pair?(array)
        return array.map { |item| extract(item, order) }.flatten(1) if nested?(array)

        [array.map { |item| position(item, order) }]
      end

      # An array holding arrays that are not plain coordinate pairs describes
      # several collections (a MultiLineString, a list of segments, …).
      def nested?(array)
        first = array.first
        first.is_a?(Array) && !numeric_pair?(first)
      end

      def position(value, order)
        case value
        when Array  then pair_position(value, order)
        when Hash   then hash_position(value)
        when String then wkt_position(value)
        else object_position(value)
        end
      end

      def pair_position(pair, order)
        raise ArgumentError, "coordinate pair must hold two numbers: #{pair.inspect}" unless numeric_pair?(pair)

        order == :lon_lat ? coordinate_pair(pair[1], pair[0]) : coordinate_pair(pair[0], pair[1])
      end

      def hash_position(hash)
        normalized = normalize_keys(hash)
        return geojson_position(normalized['coordinates']) if normalized['type'] == 'Point'

        lat = LAT_KEYS.filter_map { |key| normalized[key] }.first
        lon = LON_KEYS.filter_map { |key| normalized[key] }.first
        raise ArgumentError, "coordinate hash must hold a latitude and a longitude: #{hash.inspect}" if lat.nil? || lon.nil?

        coordinate_pair(lat, lon)
      end

      def wkt_position(value)
        positions = wkt_collections(value).flatten(1)
        raise ArgumentError, "expected a single WKT point: #{value.inspect}" unless positions.size == 1

        positions.first
      end

      # Waypoints and anything else exposing a latitude and a longitude —
      # including PostGIS/RGeo points, whose x is the longitude and y the
      # latitude.
      def object_position(value)
        return coordinate_pair(value.lat, value.lon) if value.respond_to?(:lat) && value.respond_to?(:lon)
        return coordinate_pair(value.latitude, value.longitude) if value.respond_to?(:latitude) && value.respond_to?(:longitude)
        return coordinate_pair(value.y, value.x) if value.respond_to?(:y) && value.respond_to?(:x)

        raise ArgumentError, "unsupported coordinate: #{value.inspect}"
      end

      # WKT/EWKT geometries, as handed out by PostGIS. Coordinates are "x y",
      # that is longitude first.
      def wkt_collections(value)
        raise ArgumentError, "unsupported WKT geometry: #{value.inspect}" unless wkt?(value)

        type = value[WKT_PATTERN, 1].upcase
        parts = value.scan(/\(([^()]+)\)/).flatten.map { |part| wkt_positions(part) }
        return parts.flatten(1).map { |position| [position] } if %w[POINT MULTIPOINT].include?(type)

        parts
      end

      def wkt_positions(part)
        part.split(',').map do |coordinate|
          numbers = coordinate.strip.split(/\s+/)
          raise ArgumentError, "invalid WKT coordinate: #{coordinate.strip.inspect}" if numbers.size < 2

          coordinate_pair(numbers[1], numbers[0])
        end
      end

      def append_geojson(node, collections)
        case node
        when Array then node.each { |child| append_geojson(child, collections) }
        when Hash  then append_geojson_object(normalize_keys(node), collections)
        else raise ArgumentError, "unsupported GeoJSON node: #{node.inspect}"
        end
      end

      def append_geojson_object(node, collections)
        case node['type']
        when 'FeatureCollection'  then append_geojson(geojson_array(node['features']), collections)
        when 'Feature'            then append_geojson(node['geometry'], collections) if node['geometry']
        when 'GeometryCollection' then append_geojson(geojson_array(node['geometries']), collections)
        when 'Point'              then collections << [geojson_position(node['coordinates'])]
        when 'MultiPoint'         then geojson_array(node['coordinates']).each { |pos| collections << [geojson_position(pos)] }
        when 'LineString'         then collections << geojson_positions(node['coordinates'])
        when 'MultiLineString', 'Polygon'
          geojson_array(node['coordinates']).each { |line| collections << geojson_positions(line) }
        when 'MultiPolygon'
          geojson_array(node['coordinates']).each do |polygon|
            geojson_array(polygon).each { |ring| collections << geojson_positions(ring) }
          end
        else raise ArgumentError, "unsupported GeoJSON type: #{node['type'].inspect}"
        end
      end

      def geojson_positions(coordinates)
        geojson_array(coordinates).map { |position| geojson_position(position) }
      end

      # RFC 7946 positions are [longitude, latitude] (with an optional altitude).
      def geojson_position(position)
        raise ArgumentError, "invalid GeoJSON position: #{position.inspect}" unless position.is_a?(Array) && numeric_pair?(position)

        coordinate_pair(position[1], position[0])
      end

      def geojson_array(value)
        return value if value.is_a?(Array)

        raise ArgumentError, "invalid GeoJSON coordinates: #{value.inspect}"
      end

      def coordinate_pair(lat, lon)
        latitude  = float(lat, 'latitude')
        longitude = float(lon, 'longitude')
        if latitude < -90.0 || latitude > 90.0
          raise ArgumentError,
                "latitude #{latitude} is out of range; pass coordinate_order: :lon_lat for [lon, lat] coordinates"
        end

        [latitude, longitude]
      end

      def float(value, name)
        Float(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} is not a number: #{value.inspect}"
      end

      def numeric_pair?(value)
        value.is_a?(Array) && value.size >= 2 && numeric?(value[0]) && numeric?(value[1])
      end

      def numeric?(value)
        value.is_a?(Numeric) || (value.is_a?(String) && !Float(value, exception: false).nil?)
      end

      def normalize_keys(hash)
        hash.transform_keys { |key| key.to_s.downcase }
      end

      def parse_json(text)
        JSON.parse(text)
      rescue JSON::ParserError => e
        raise ArgumentError, "invalid GeoJSON: #{e.message}"
      end

      def file?(value)
        return false if value.length > MAX_PATH_LENGTH || value.match?(/[\n\0]/)

        File.file?(value)
      end

      def xml?(content)
        content.lstrip.start_with?('<')
      end

      def json?(content)
        content.lstrip.start_with?('{', '[')
      end

      def wkt?(value)
        value.match?(WKT_PATTERN)
      end
    end
  end
end
