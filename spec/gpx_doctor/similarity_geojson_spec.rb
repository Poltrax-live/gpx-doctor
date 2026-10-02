# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe GpxDoctor::Similarity, 'comparing GeoJSON' do
  # sample.gpx holds a route from [48.21, 16.36] to [48.22, 16.37] and a track
  # segment from [48.23, 16.38] to [48.24, 16.39].
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:geojson)      { GpxDoctor::GeoJsonBuilder.build(GpxDoctor::Parser.parse(fixture_path)) }

  describe '.geojson_compare' do
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

  describe 'point order' do
    it 'returns 1.0 for the GeoJSON of a reversed copy' do
      Dir.mktmpdir do |dir|
        result = GpxDoctor::Parser.parse(fixture_path)
        result.routes.each { |route| route.points = route.points.reverse }
        result.tracks.each do |track|
          track.segments = track.segments.reverse
          track.segments.each { |segment| segment.points = segment.points.reverse }
        end

        path = File.join(dir, 'reversed.gpx')
        GpxDoctor::Builder.build_file(result, path)
        reversed = GpxDoctor::GeoJsonBuilder.build(GpxDoctor::Parser.parse(path))

        expect(described_class.geojson_compare(fixture_path, reversed)).to eq(1.0)
      end
    end
  end
end
