# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe GpxDoctor::Similarity, 'comparing GPX files' do
  # sample.gpx holds a route from [48.21, 16.36] to [48.22, 16.37], a track
  # segment from [48.23, 16.38] to [48.24, 16.39] and one standalone waypoint
  # at [48.2093723, 16.356099], roughly 300 m away from the route.
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }

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
  end

  describe 'point order' do
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
