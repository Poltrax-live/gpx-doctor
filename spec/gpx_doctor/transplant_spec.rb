# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe GpxDoctor::Transplant do
  # n1, n2, ..., n9 along a line; m1 sits close to n2, m3 close to n8.
  let(:route_points) { (1..9).map { |i| point("n#{i}", 16.0 + (i * 0.01)) } }
  let(:transplant_points) do
    [point('m1', 16.0201, lat: 48.0001), point('m2', 16.05, lat: 48.0002), point('m3', 16.0801, lat: 48.0001)]
  end

  def point(name, lon, lat: 48.0)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, name: name)
  end

  def result_with_route(points)
    GpxDoctor::Parser::Result.new(
      waypoints: [],
      routes: [GpxDoctor::Models::Route.new(name: 'Route', points: points)],
      tracks: [],
      metadata: GpxDoctor::Models::Metadata.new(name: 'Original')
    )
  end

  let(:original)    { result_with_route(route_points) }
  let(:transplant)  { result_with_route(transplant_points) }

  describe '.graft' do
    it 'replaces the matching section with the transplant, keeping only the surviving points' do
      result = described_class.graft(original, transplant)
      expect(result.routes.first.points.map(&:name)).to eq(%w[n1 m1 m2 m3 n9])
    end

    it 'does not mutate the original result' do
      described_class.graft(original, transplant)
      expect(original.routes.first.points.map(&:name)).to eq(%w[n1 n2 n3 n4 n5 n6 n7 n8 n9])
    end

    it 'does not mutate the transplant result' do
      described_class.graft(original, transplant)
      expect(transplant.routes.first.points.map(&:name)).to eq(%w[m1 m2 m3])
    end

    it 'preserves metadata and other fields of the original result' do
      result = described_class.graft(original, transplant)
      expect(result.metadata.name).to eq('Original')
    end

    it 'preserves the route name of the spliced route' do
      result = described_class.graft(original, transplant)
      expect(result.routes.first.name).to eq('Route')
    end

    it 'grafts onto a track segment' do
      track_original = GpxDoctor::Parser::Result.new(
        waypoints: [], routes: [],
        tracks: [GpxDoctor::Models::Track.new(segments: [GpxDoctor::Models::TrackSegment.new(points: route_points)])],
        metadata: nil
      )
      result = described_class.graft(track_original, transplant)
      expect(result.tracks.first.segments.first.points.map(&:name)).to eq(%w[n1 m1 m2 m3 n9])
    end

    it 'accepts GPX file paths' do
      Dir.mktmpdir do |dir|
        original_path = File.join(dir, 'original.gpx')
        transplant_path = File.join(dir, 'transplant.gpx')
        GpxDoctor::Builder.build_file(original, original_path)
        GpxDoctor::Builder.build_file(transplant, transplant_path)

        result = described_class.graft(original_path, transplant_path)
        expect(result.routes.first.points.map(&:name)).to eq(%w[n1 m1 m2 m3 n9])
      end
    end

    it 'accepts GPX XML strings' do
      result = described_class.graft(GpxDoctor::Builder.build(original), GpxDoctor::Builder.build(transplant))
      expect(result.routes.first.points.map(&:name)).to eq(%w[n1 m1 m2 m3 n9])
    end

    it 'raises when the transplant start/end is too far from the route' do
      far_transplant = result_with_route([point('f1', 20.0, lat: 50.0), point('f2', 20.01, lat: 50.0)])
      expect { described_class.graft(original, far_transplant, tolerance: 25.0) }.to raise_error(ArgumentError, /tolerance/)
    end

    it 'skips the tolerance check when tolerance is nil' do
      # Both far points sit closest to n9 (the point with the least longitude
      # gap), so the whole tail of the route is replaced by the transplant.
      far_transplant = result_with_route([point('f1', 20.0, lat: 50.0), point('f2', 20.01, lat: 50.0)])
      result = described_class.graft(original, far_transplant, tolerance: nil)
      expect(result.routes.first.points.map(&:name)).to eq(%w[n1 n2 n3 n4 n5 n6 n7 n8 f1 f2])
    end

    it 'raises when the transplant end matches before its start on the route' do
      reversed = result_with_route([point('m3', 16.0801, lat: 48.0001), point('m1', 16.0201, lat: 48.0001)])
      expect { described_class.graft(original, reversed) }.to raise_error(ArgumentError, /lies before its start/)
    end

    it 'raises when the original has no route or track points' do
      empty = GpxDoctor::Parser::Result.new(waypoints: [], routes: [], tracks: [], metadata: nil)
      expect { described_class.graft(empty, transplant) }.to raise_error(ArgumentError, /original GPX holds no/)
    end

    it 'raises when the transplant has no route or track points' do
      empty = GpxDoctor::Parser::Result.new(waypoints: [], routes: [], tracks: [], metadata: nil)
      expect { described_class.graft(original, empty) }.to raise_error(ArgumentError, /transplant GPX holds no/)
    end
  end
end
