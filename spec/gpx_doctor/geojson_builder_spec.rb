# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe GpxDoctor::GeoJsonBuilder do
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:parsed)       { GpxDoctor::Parser.parse(fixture_path) }
  let(:json_string)  { described_class.build(parsed) }
  let(:doc)          { JSON.parse(json_string) }

  describe '.build' do
    it 'returns a String' do
      expect(json_string).to be_a(String)
    end

    it 'produces valid JSON' do
      expect { JSON.parse(json_string) }.not_to raise_error
    end

    it 'produces a GeoJSON FeatureCollection' do
      expect(doc['type']).to eq('FeatureCollection')
    end

    it 'has a features array' do
      expect(doc['features']).to be_an(Array)
    end

    context 'waypoints' do
      let(:point_features) do
        doc['features'].select { |f| f['geometry']['type'] == 'Point' }
      end

      it 'serialises one waypoint as a Point feature' do
        expect(point_features.length).to eq(1)
      end

      it 'uses [lon, lat] coordinate order' do
        coords = point_features.first['geometry']['coordinates']
        expect(coords[0]).to be_within(0.0001).of(16.356099) # lon
        expect(coords[1]).to be_within(0.0001).of(48.2093723) # lat
      end

      it 'includes elevation as third coordinate element' do
        coords = point_features.first['geometry']['coordinates']
        expect(coords[2]).to eq(160.0)
      end

      it 'includes name in properties' do
        expect(point_features.first['properties']['name']).to eq('Waypoint 1')
      end

      it 'includes desc in properties' do
        expect(point_features.first['properties']['desc']).to eq('A standalone waypoint')
      end

      it 'includes time as ISO 8601 in properties' do
        time_str = point_features.first['properties']['time']
        expect { Time.parse(time_str) }.not_to raise_error
      end
    end

    context 'routes' do
      let(:line_features) do
        doc['features'].select { |f| f['geometry']['type'] == 'LineString' }
      end

      it 'serialises one route as a LineString feature' do
        expect(line_features.length).to eq(1)
      end

      it 'includes route name in properties' do
        expect(line_features.first['properties']['name']).to eq('Route 1')
      end

      it 'serialises route points as coordinates' do
        expect(line_features.first['geometry']['coordinates'].length).to eq(2)
      end

      it 'uses [lon, lat] coordinate order for route points' do
        first_coord = line_features.first['geometry']['coordinates'].first
        expect(first_coord[0]).to be_within(0.0001).of(16.36) # lon
        expect(first_coord[1]).to be_within(0.0001).of(48.21) # lat
      end
    end

    context 'tracks' do
      let(:multiline_features) do
        doc['features'].select { |f| f['geometry']['type'] == 'MultiLineString' }
      end

      it 'serialises one track as a MultiLineString feature' do
        expect(multiline_features.length).to eq(1)
      end

      it 'includes track name in properties' do
        expect(multiline_features.first['properties']['name']).to eq('Track 1')
      end

      it 'serialises track segments as sub-arrays' do
        expect(multiline_features.first['geometry']['coordinates'].length).to eq(1)
      end

      it 'serialises track points within segment' do
        segment_coords = multiline_features.first['geometry']['coordinates'].first
        expect(segment_coords.length).to eq(2)
      end

      it 'uses [lon, lat] coordinate order for track points' do
        first_coord = multiline_features.first['geometry']['coordinates'].first.first
        expect(first_coord[0]).to be_within(0.0001).of(16.38) # lon
        expect(first_coord[1]).to be_within(0.0001).of(48.23) # lat
      end
    end

    context 'total feature count' do
      it 'produces one feature per waypoint, route and track' do
        # sample.gpx has 1 waypoint, 1 route, 1 track
        expect(doc['features'].length).to eq(3)
      end
    end
  end

  describe 'RFC 7946 compliance' do
    context 'properties member' do
      it 'uses null for features with no properties' do
        # Create a minimal waypoint with no name/desc/etc
        minimal_wpt = GpxDoctor::Models::Waypoint.new(lat: 48.0, lon: 16.0)
        result = GpxDoctor::Parser::Result.new(
          waypoints: [minimal_wpt],
          routes: [],
          tracks: [],
          metadata: nil
        )
        json_str = described_class.build(result)
        geojson = JSON.parse(json_str)
        
        expect(geojson['features'][0]['properties']).to be_nil
      end

      it 'uses object for features with properties' do
        # Waypoints in sample.gpx have properties
        point_features = doc['features'].select { |f| f['geometry']['type'] == 'Point' }
        expect(point_features.first['properties']).to be_a(Hash)
        expect(point_features.first['properties']).not_to be_empty
      end
    end

    context 'LineString validation' do
      it 'filters out routes with fewer than 2 points' do
        # Create route with only 1 point
        single_pt_route = GpxDoctor::Models::Route.new(
          name: 'Invalid Route',
          points: [GpxDoctor::Models::Waypoint.new(lat: 48.0, lon: 16.0)]
        )
        result = GpxDoctor::Parser::Result.new(
          waypoints: [],
          routes: [single_pt_route],
          tracks: [],
          metadata: nil
        )
        json_str = described_class.build(result)
        geojson = JSON.parse(json_str)
        
        expect(geojson['features'].length).to eq(0)
      end

      it 'includes routes with 2 or more points' do
        # sample.gpx route has 2 points
        line_features = doc['features'].select { |f| f['geometry']['type'] == 'LineString' }
        expect(line_features.length).to eq(1)
        expect(line_features.first['geometry']['coordinates'].length).to be >= 2
      end
    end

    context 'MultiLineString validation' do
      it 'filters out track segments with fewer than 2 points' do
        # Create track with an invalid segment (1 point) and a valid one (2 points)
        invalid_seg = GpxDoctor::Models::TrackSegment.new(
          points: [GpxDoctor::Models::Waypoint.new(lat: 48.0, lon: 16.0)]
        )
        valid_seg = GpxDoctor::Models::TrackSegment.new(
          points: [
            GpxDoctor::Models::Waypoint.new(lat: 48.1, lon: 16.1),
            GpxDoctor::Models::Waypoint.new(lat: 48.2, lon: 16.2)
          ]
        )
        track = GpxDoctor::Models::Track.new(
          name: 'Mixed Track',
          segments: [invalid_seg, valid_seg]
        )
        result = GpxDoctor::Parser::Result.new(
          waypoints: [],
          routes: [],
          tracks: [track],
          metadata: nil
        )
        json_str = described_class.build(result)
        geojson = JSON.parse(json_str)
        
        multiline_features = geojson['features'].select { |f| f['geometry']['type'] == 'MultiLineString' }
        expect(multiline_features.length).to eq(1)
        # Should only have the valid segment
        expect(multiline_features.first['geometry']['coordinates'].length).to eq(1)
        expect(multiline_features.first['geometry']['coordinates'][0].length).to eq(2)
      end

      it 'filters out tracks with no valid segments' do
        # Create track with only invalid segments
        invalid_seg = GpxDoctor::Models::TrackSegment.new(
          points: [GpxDoctor::Models::Waypoint.new(lat: 48.0, lon: 16.0)]
        )
        track = GpxDoctor::Models::Track.new(
          name: 'Invalid Track',
          segments: [invalid_seg]
        )
        result = GpxDoctor::Parser::Result.new(
          waypoints: [],
          routes: [],
          tracks: [track],
          metadata: nil
        )
        json_str = described_class.build(result)
        geojson = JSON.parse(json_str)
        
        expect(geojson['features'].length).to eq(0)
      end
    end

    context 'coordinate order' do
      it 'uses [longitude, latitude] order for all geometries' do
        # Test Point
        point_features = doc['features'].select { |f| f['geometry']['type'] == 'Point' }
        coords = point_features.first['geometry']['coordinates']
        expect(coords[0]).to be_between(-180, 180) # longitude range
        expect(coords[1]).to be_between(-90, 90)   # latitude range
        
        # Test LineString
        line_features = doc['features'].select { |f| f['geometry']['type'] == 'LineString' }
        line_coords = line_features.first['geometry']['coordinates'].first
        expect(line_coords[0]).to be_between(-180, 180)
        expect(line_coords[1]).to be_between(-90, 90)
        
        # Test MultiLineString
        multiline_features = doc['features'].select { |f| f['geometry']['type'] == 'MultiLineString' }
        multi_coords = multiline_features.first['geometry']['coordinates'][0][0]
        expect(multi_coords[0]).to be_between(-180, 180)
        expect(multi_coords[1]).to be_between(-90, 90)
      end
    end
  end

  describe '.build_file' do
    it 'writes JSON to disk and returns the JSON string' do
      Dir.mktmpdir do |dir|
        path   = File.join(dir, 'output.geojson')
        result = described_class.build_file(parsed, path)

        expect(File.exist?(path)).to be true
        expect(File.read(path)).to eq(result)
        expect(result).to be_a(String)
      end
    end

    it 'produces a file with valid GeoJSON' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'output.geojson')
        described_class.build_file(parsed, path)
        content = JSON.parse(File.read(path))
        expect(content['type']).to eq('FeatureCollection')
      end
    end
  end
end
