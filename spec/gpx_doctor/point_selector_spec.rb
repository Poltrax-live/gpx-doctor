# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::PointSelector do
  subject(:selector) { described_class.new }

  SELECTOR_METERS_PER_DEG = GpxDoctor::DistanceCalculator::METERS_PER_DEGREE_LAT

  def make_waypoint(lat:, lon:, ele: nil, time: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele, time: time)
  end

  describe '#select' do
    it 'returns nil input unchanged' do
      expect(selector.select(nil, 5)).to be_nil
    end

    it 'returns the array unchanged when max_points is zero' do
      pts = [make_waypoint(lat: 48.0, lon: 16.0)]
      expect(selector.select(pts, 0)).to eq(pts)
    end

    it 'returns the array unchanged when it has fewer points than max_points' do
      pts = [make_waypoint(lat: 48.0, lon: 16.0), make_waypoint(lat: 48.001, lon: 16.0)]
      expect(selector.select(pts, 10)).to eq(pts)
    end

    it 'returns the array unchanged when it has exactly max_points' do
      pts = [make_waypoint(lat: 48.0, lon: 16.0), make_waypoint(lat: 48.001, lon: 16.0)]
      expect(selector.select(pts, 2)).to eq(pts)
    end

    context 'when selecting 1 point' do
      let(:pts) do
        (0..9).map { |i| make_waypoint(lat: 48.0 + i * 0.001, lon: 16.0) }
      end

      it 'returns only the first point' do
        result = selector.select(pts, 1)
        expect(result.length).to eq(1)
        expect(result.first).to eq(pts.first)
      end
    end

    context 'when selecting 2 points from a longer sequence' do
      let(:pts) do
        (0..9).map { |i| make_waypoint(lat: 48.0 + i * 0.001, lon: 16.0) }
      end

      it 'returns first and last points' do
        result = selector.select(pts, 2)
        expect(result.length).to eq(2)
        expect(result.first).to eq(pts.first)
        expect(result.last).to eq(pts.last)
      end
    end

    context 'with evenly spaced points (equal distance between each)' do
      # 10 points, each ~111 m apart (0.001 deg lat)
      let(:pts) do
        (0..9).map { |i| make_waypoint(lat: 48.0 + i * 0.001, lon: 16.0) }
      end

      it 'selects the correct number of points' do
        result = selector.select(pts, 5)
        expect(result.length).to eq(5)
      end

      it 'always includes first and last point' do
        result = selector.select(pts, 5)
        expect(result.first).to eq(pts.first)
        expect(result.last).to eq(pts.last)
      end

      it 'selects points with approximately equal distance spread' do
        result = selector.select(pts, 5)
        # With 10 equidistant points, selecting 5 should give indices 0, 2 or 3, 4 or 5, 6 or 7, 9
        # The gaps between consecutive selected points should be roughly equal
        gaps = result.each_cons(2).map do |a, b|
          dlat_m = (b.lat - a.lat) * SELECTOR_METERS_PER_DEG
          dlat_m.abs
        end
        min_gap = gaps.min
        max_gap = gaps.max
        # Gaps should be within a factor of 2 of each other (roughly equal)
        expect(max_gap / min_gap).to be < 2.5
      end
    end

    context 'with unevenly spaced points' do
      # First half: tightly packed; second half: one big jump
      let(:pts) do
        tight = (0..7).map { |i| make_waypoint(lat: 48.0 + i * 0.0001, lon: 16.0) }
        far   = [make_waypoint(lat: 48.02, lon: 16.0), make_waypoint(lat: 48.04, lon: 16.0)]
        tight + far
      end

      it 'selects the requested number of points' do
        result = selector.select(pts, 4)
        expect(result.length).to eq(4)
      end

      it 'includes the first and last point' do
        result = selector.select(pts, 4)
        expect(result.first).to eq(pts.first)
        expect(result.last).to eq(pts.last)
      end
    end

    context 'when all points are at the same location (zero total distance)' do
      let(:pts) do
        5.times.map { make_waypoint(lat: 48.0, lon: 16.0) }
      end

      it 'returns the correct number of points without raising' do
        result = selector.select(pts, 3)
        expect(result.length).to eq(3)
      end
    end
  end
end
