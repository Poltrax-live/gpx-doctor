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
