# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe GpxDoctor::Similarity do
  # sample.gpx holds a route from [48.21, 16.36] to [48.22, 16.37], a track
  # segment from [48.23, 16.38] to [48.24, 16.39] and one standalone waypoint
  # at [48.2093723, 16.356099], roughly 300 m away from the route.
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:on_path)      { [48.21, 16.36] }
  let(:off_path)     { [49.21, 17.36] }

  def shifted_file(dir, lat_shift: 0.0, points: :all, name: 'shifted.gpx')
    result = GpxDoctor::Parser.parse(fixture_path)
    shifted = points == :all ? result.points : result.tracks.flat_map(&:points)
    shifted.each { |point| point.lat += lat_shift }

    path = File.join(dir, name)
    GpxDoctor::Builder.build_file(result, path)
    path
  end

  def reversed_file(dir, lat_shift: 0.0, name: 'reversed.gpx')
    result = GpxDoctor::Parser.parse(fixture_path)
    result.points.each { |point| point.lat += lat_shift }
    result.routes.each { |route| route.points = route.points.reverse }
    result.tracks.each do |track|
      track.segments = track.segments.reverse
      track.segments.each { |segment| segment.points = segment.points.reverse }
    end

    path = File.join(dir, name)
    GpxDoctor::Builder.build_file(result, path)
    path
  end

  describe '.compare_files' do
    it 'returns 1.0 when a file is compared with itself' do
      expect(described_class.compare_files(fixture_path, fixture_path)).to eq(1.0)
    end

    it 'returns 1.0 for a rebuilt copy of the same file' do
      Dir.mktmpdir do |dir|
        copy = shifted_file(dir, name: 'copy.gpx')
        expect(described_class.compare_files(fixture_path, copy)).to eq(1.0)
      end
    end

    it 'returns 1.0 for a track running a few metres beside the path' do
      Dir.mktmpdir do |dir|
        beside = shifted_file(dir, lat_shift: 0.00009) # ~10 m north
        expect(described_class.compare_files(fixture_path, beside)).to eq(1.0)
      end
    end

    it 'returns 0.0 for a track that is nowhere near the path' do
      Dir.mktmpdir do |dir|
        far = shifted_file(dir, lat_shift: 1.0)
        expect(described_class.compare_files(fixture_path, far)).to eq(0.0)
      end
    end

    it 'returns the fraction of compared points that follow the path' do
      Dir.mktmpdir do |dir|
        half = shifted_file(dir, lat_shift: 1.0, points: :track)
        expect(described_class.compare_files(fixture_path, half)).to eq(0.5)
      end
    end

    it 'counts points further away when the tolerance is raised' do
      Dir.mktmpdir do |dir|
        beside = shifted_file(dir, lat_shift: 0.0009) # ~100 m north
        expect(described_class.compare_files(fixture_path, beside)).to eq(0.0)
        expect(described_class.compare_files(fixture_path, beside, tolerance: 150)).to eq(1.0)
      end
    end

    it 'raises when a file does not exist' do
      expect { described_class.compare_files(fixture_path, 'does_not_exist.gpx') }
        .to raise_error(ArgumentError, /file not found/)
    end
  end

  describe '.compare' do
    it 'accepts an array of [lat, lon] pairs' do
      expect(described_class.compare(fixture_path, [on_path, [48.22, 16.37]])).to eq(1.0)
    end

    it 'accepts a single coordinate pair' do
      expect(described_class.compare(fixture_path, on_path)).to eq(1.0)
    end

    it 'reads pairs as [lon, lat] when asked to' do
      expect(described_class.compare(fixture_path, [[16.36, 48.21]], coordinate_order: :lon_lat)).to eq(1.0)
    end

    it 'accepts hashes keyed by lat/lon, latitude/longitude or x/y' do
      coordinates = [
        { lat: 48.21, lon: 16.36 },
        { 'latitude' => 48.22, 'longitude' => 16.37 },
        { x: 16.38, y: 48.23 }
      ]
      expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
    end

    it 'accepts waypoints and anything else answering to lat and lon' do
      waypoint = GpxDoctor::Models::Waypoint.new(lat: 48.21, lon: 16.36)
      expect(described_class.compare(fixture_path, [waypoint])).to eq(1.0)
    end

    it 'accepts a parse result' do
      result = GpxDoctor::Parser.parse(fixture_path)
      expect(described_class.compare(fixture_path, result)).to eq(1.0)
    end

    it 'accepts a route or a track segment' do
      result = GpxDoctor::Parser.parse(fixture_path)
      expect(described_class.compare(fixture_path, result.routes.first)).to eq(1.0)
      expect(described_class.compare(fixture_path, result.tracks.first.segments.first)).to eq(1.0)
    end

    it 'accepts GPX XML' do
      xml = File.read(fixture_path)
      expect(described_class.compare(xml, xml)).to eq(1.0)
    end

    it 'accepts PostGIS WKT geometries' do
      expect(described_class.compare(fixture_path, 'SRID=4326;POINT(16.36 48.21)')).to eq(1.0)
      expect(described_class.compare(fixture_path, 'LINESTRING(16.36 48.21, 16.37 48.22)')).to eq(1.0)
      expect(described_class.compare(fixture_path, 'MULTIPOINT((16.36 48.21), (17.36 49.21))')).to eq(0.5)
    end

    it 'counts a coordinate lying between two reference points' do
      # Halfway along the track segment: ~650 m from either of its points, yet
      # exactly on the path they describe.
      expect(described_class.compare(fixture_path, [[48.235, 16.385]])).to eq(1.0)
    end

    it 'returns 0.0 when nothing follows the path' do
      expect(described_class.compare(fixture_path, [off_path, [49.22, 17.37]])).to eq(0.0)
    end

    it 'rounds the fraction of matching points' do
      expect(described_class.compare(fixture_path, [on_path, [48.22, 16.37], off_path])).to eq(0.6667)
    end

    it 'ignores the standalone waypoints of the compared file' do
      # The waypoint of sample.gpx sits ~300 m off the route; were it compared,
      # the file could not fully match itself.
      expect(described_class.compare(fixture_path, fixture_path)).to eq(1.0)
    end

    it 'uses standalone waypoints when a file holds nothing else' do
      result = GpxDoctor::Parser::Result.new(
        waypoints: [GpxDoctor::Models::Waypoint.new(lat: 48.21, lon: 16.36)],
        routes: [],
        tracks: []
      )
      expect(described_class.compare(fixture_path, result)).to eq(1.0)
    end

    context 'with sample_interval' do
      # The straight line from the start of the route to the end of the track
      # runs over the gap between the two, which is not part of the path.
      let(:coordinates) { [[48.21, 16.36], [48.24, 16.39]] }

      it 'only looks at the given points by default' do
        expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
      end

      it 'also looks between the given points when asked to' do
        score = described_class.compare(fixture_path, coordinates, sample_interval: 50)
        expect(score).to be > 0.5
        expect(score).to be < 0.8
      end

      it 'keeps a full match when the sampled line follows the path' do
        on_segment = [[48.23, 16.38], [48.24, 16.39]]
        expect(described_class.compare(fixture_path, on_segment, sample_interval: 50)).to eq(1.0)
      end
    end

    context 'with invalid input' do
      it 'raises for an unsupported source' do
        expect { described_class.compare(fixture_path, 'not a track') }
          .to raise_error(ArgumentError, /unsupported source/)
      end

      it 'raises for an unsupported coordinate' do
        expect { described_class.compare(fixture_path, [{ foo: 1 }]) }
          .to raise_error(ArgumentError, /latitude and a longitude/)
      end

      it 'raises when there is nothing to compare' do
        expect { described_class.compare(fixture_path, []) }
          .to raise_error(ArgumentError, /no points to compare/)
      end

      it 'raises when a latitude is out of range' do
        expect { described_class.compare(fixture_path, [[116.36, 48.21]]) }
          .to raise_error(ArgumentError, /out of range/)
      end

      it 'raises for a tolerance that is not a positive number' do
        expect { described_class.compare(fixture_path, [on_path], tolerance: 0) }
          .to raise_error(ArgumentError, /tolerance must be positive/)
        expect { described_class.compare(fixture_path, [on_path], tolerance: nil) }
          .to raise_error(ArgumentError, /tolerance must be a number/)
      end

      it 'raises for an unknown coordinate order' do
        expect { described_class.compare(fixture_path, [on_path], coordinate_order: :whatever) }
          .to raise_error(ArgumentError, /coordinate_order/)
      end
    end
  end

  describe 'point order' do
    # A square lap of roughly 1.1 km a side, closed by repeating its first point
    # the way a recorded loop does.
    let(:circular_route) do
      [[48.20, 16.30], [48.21, 16.30], [48.21, 16.31], [48.20, 16.31], [48.20, 16.30]]
    end

    it 'returns 1.0 for a file compared with its reversed copy' do
      Dir.mktmpdir do |dir|
        reversed = reversed_file(dir)
        expect(described_class.compare_files(fixture_path, reversed)).to eq(1.0)
        expect(described_class.compare_files(reversed, fixture_path)).to eq(1.0)
      end
    end

    it 'keeps a reversed copy at 1.0 when the stretches between points count too' do
      Dir.mktmpdir do |dir|
        reversed = reversed_file(dir)
        expect(described_class.compare_files(fixture_path, reversed, sample_interval: 50)).to eq(1.0)
      end
    end

    it 'still misses a reversed copy that leaves the path' do
      Dir.mktmpdir do |dir|
        far = reversed_file(dir, lat_shift: 1.0)
        expect(described_class.compare_files(fixture_path, far)).to eq(0.0)
      end
    end

    it 'returns 1.0 for the GeoJSON of a reversed copy' do
      Dir.mktmpdir do |dir|
        geojson = GpxDoctor::GeoJsonBuilder.build(GpxDoctor::Parser.parse(reversed_file(dir)))
        expect(described_class.geojson_compare(fixture_path, geojson)).to eq(1.0)
      end
    end

    it 'returns 1.0 for a reversed array of coordinates' do
      coordinates = [[48.21, 16.36], [48.215, 16.365], [48.22, 16.37]]
      expect(described_class.compare(fixture_path, coordinates.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'ignores the order the compared points come in' do
      coordinates = [[48.21, 16.36], [48.24, 16.39], [48.23, 16.38], [48.22, 16.37]]
      expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
    end

    it 'returns 1.0 for a track that doubles back on itself' do
      there = [[48.23, 16.38], [48.235, 16.385], [48.24, 16.39]]
      there_and_back = there + there[0..-2].reverse
      expect(described_class.compare(fixture_path, there_and_back, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route ridden the other way round' do
      expect(described_class.compare(circular_route, circular_route.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route started at another of its points' do
      rotated = circular_route[0..-2].rotate(2)
      rotated += [rotated.first]

      expect(described_class.compare(circular_route, rotated, sample_interval: 50)).to eq(1.0)
      expect(described_class.compare(rotated, circular_route, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route started between two of its points' do
      # Halfway up the first side of the lap, so the start is not one of the
      # recorded points at all.
      halfway = [48.205, 16.30]
      rotated = [halfway] + circular_route[1..-1] + [halfway]

      expect(described_class.compare(circular_route, rotated, sample_interval: 50)).to eq(1.0)
      expect(described_class.compare(circular_route, rotated.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'still misses a circular route that runs beside the lap' do
      beside = circular_route.reverse.map { |lat, lon| [lat, lon + 0.0015] } # ~110 m east
      expect(described_class.compare(circular_route, beside, sample_interval: 50)).to be < 0.5
    end
  end

  describe '.geojson_compare' do
    let(:geojson) { GpxDoctor::GeoJsonBuilder.build(GpxDoctor::Parser.parse(fixture_path)) }

    it 'returns 1.0 for the GeoJSON of the same file' do
      expect(described_class.geojson_compare(fixture_path, geojson)).to eq(1.0)
    end

    it 'accepts an already parsed document' do
      expect(described_class.geojson_compare(fixture_path, JSON.parse(geojson))).to eq(1.0)
    end

    it 'accepts a GeoJSON file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'track.geojson')
        File.write(path, geojson)
        expect(described_class.geojson_compare(fixture_path, path)).to eq(1.0)
      end
    end

    it 'accepts a bare geometry with symbol keys' do
      geometry = { type: 'LineString', coordinates: [[16.36, 48.21], [16.37, 48.22]] }
      expect(described_class.geojson_compare(fixture_path, geometry)).to eq(1.0)
    end

    it 'reads positions as [lon, lat]' do
      swapped = { 'type' => 'LineString', 'coordinates' => [[48.21, 16.36], [48.22, 16.37]] }
      expect(described_class.geojson_compare(fixture_path, swapped)).to eq(0.0)
    end

    it 'reads every geometry of a feature collection' do
      document = {
        'type' => 'FeatureCollection',
        'features' => [
          { 'type' => 'Feature', 'properties' => nil,
            'geometry' => { 'type' => 'LineString', 'coordinates' => [[16.36, 48.21], [16.37, 48.22]] } },
          { 'type' => 'Feature', 'properties' => nil,
            'geometry' => { 'type' => 'LineString', 'coordinates' => [[17.36, 49.21], [17.37, 49.22]] } }
        ]
      }
      expect(described_class.geojson_compare(fixture_path, document)).to eq(0.5)
    end

    it 'uses isolated points when the document describes no path' do
      document = { 'type' => 'MultiPoint', 'coordinates' => [[16.36, 48.21], [17.36, 49.21]] }
      expect(described_class.geojson_compare(fixture_path, document)).to eq(0.5)
    end

    it 'raises for invalid GeoJSON' do
      expect { described_class.geojson_compare(fixture_path, '{ not json') }
        .to raise_error(ArgumentError, /invalid GeoJSON/)
      expect { described_class.geojson_compare(fixture_path, { 'type' => 'Rectangle' }) }
        .to raise_error(ArgumentError, /unsupported GeoJSON type/)
    end
  end

  describe 'larger files' do
    let(:gory_path) { File.expand_path('../fixtures/gory.gpx', __dir__) }

    it 'fully matches a long activity against itself' do
      expect(described_class.compare_files(gory_path, gory_path)).to eq(1.0)
    end

    it 'fully matches a long activity against its reversed copy' do
      Dir.mktmpdir do |dir|
        result = GpxDoctor::Parser.parse(gory_path)
        result.tracks.each do |track|
          track.segments = track.segments.reverse
          track.segments.each { |segment| segment.points = segment.points.reverse }
        end

        reversed = File.join(dir, 'gory_reversed.gpx')
        GpxDoctor::Builder.build_file(result, reversed)
        expect(described_class.compare_files(gory_path, reversed)).to eq(1.0)
      end
    end

    it 'does not match an unrelated activity' do
      expect(described_class.compare_files(gory_path, fixture_path)).to eq(0.0)
    end
  end
end
