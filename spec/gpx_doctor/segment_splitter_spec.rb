# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::SegmentSplitter do
  subject(:splitter) { described_class.new }

  METERS_PER_DEG = GpxDoctor::DistanceCalculator::METERS_PER_DEGREE_LAT

  def make_waypoint(lat:, lon:, ele: nil, time: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele, time: time)
  end

  describe '#split' do
    it 'returns the original array unchanged for nil input' do
      expect(splitter.split(nil, 100)).to be_nil
    end

    it 'returns the original array unchanged for a single point' do
      wp = make_waypoint(lat: 48.0, lon: 16.0)
      result = splitter.split([wp], 100)
      expect(result).to eq([wp])
    end

    context 'when all consecutive distances are within the limit' do
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0) }
      let(:wp2) { make_waypoint(lat: 48.0001, lon: 16.0) } # ~11 m apart

      it 'returns the same two points unchanged' do
        result = splitter.split([wp1, wp2], 100)
        expect(result).to eq([wp1, wp2])
      end
    end

    context 'when a pair exceeds the limit' do
      # 1 degree lat = 111_320 m; 0.001 deg ≈ 111.32 m
      # Use max_distance 50 → ceil(111.32 / 50) = 3 segments → 2 extra points
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.0) }
      let(:result) { splitter.split([wp1, wp2], 50) }

      it 'inserts the correct number of intermediate points' do
        # ceil(~111.32 / 50) = 3 segments → 2 intermediate points
        expect(result.length).to eq(4)
      end

      it 'keeps the original endpoints' do
        expect(result.first).to eq(wp1)
        expect(result.last).to eq(wp2)
      end

      it 'places intermediate points at evenly spaced latitudes' do
        intermediate = result[1...-1]
        # 3 segments: fractions 1/3 and 2/3
        expected_lats = [1.0 / 3, 2.0 / 3].map { |f| 48.0 + f * 0.001 }
        intermediate.each_with_index do |pt, i|
          expect(pt.lat).to be_within(1e-9).of(expected_lats[i])
          expect(pt.lon).to be_within(1e-9).of(16.0)
        end
      end

      it 'ensures no sub-segment exceeds the max_distance' do
        result.each_cons(2) do |a, b|
          dlat_m = (b.lat - a.lat) * METERS_PER_DEG
          avg_lat_rad = (a.lat + b.lat) / 2.0 * Math::PI / 180.0
          dlon_m = (b.lon - a.lon) * METERS_PER_DEG * Math.cos(avg_lat_rad)
          dist = Math.sqrt(dlat_m**2 + dlon_m**2)
          expect(dist).to be <= 50
        end
      end
    end

    context 'interpolating elevation' do
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.0, ele: 200.0) }

      it 'linearly interpolates elevation when both endpoints have it' do
        result = splitter.split([wp1, wp2], 50)
        intermediate = result[1...-1]
        expect(intermediate.first.ele).to be_within(0.01).of(100.0 + (1.0 / 3) * 100.0)
        expect(intermediate.last.ele).to be_within(0.01).of(100.0 + (2.0 / 3) * 100.0)
      end

      it 'sets elevation to nil when start point has no elevation' do
        wp_no_ele = make_waypoint(lat: 48.0, lon: 16.0)
        result = splitter.split([wp_no_ele, wp2], 50)
        result[1...-1].each { |pt| expect(pt.ele).to be_nil }
      end

      it 'sets elevation to nil when end point has no elevation' do
        wp_no_ele = make_waypoint(lat: 48.001, lon: 16.0)
        result = splitter.split([wp1, wp_no_ele], 50)
        result[1...-1].each { |pt| expect(pt.ele).to be_nil }
      end
    end

    context 'interpolating time' do
      let(:t1) { Time.utc(2024, 1, 1, 10, 0, 0) }
      let(:t2) { Time.utc(2024, 1, 1, 10, 0, 30) } # 30 seconds later
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0, time: t1) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.0, time: t2) }

      it 'linearly interpolates time when both endpoints have it' do
        result = splitter.split([wp1, wp2], 50)
        intermediate = result[1...-1]
        # fraction 1/3 → t1 + 10s, fraction 2/3 → t1 + 20s
        expect(intermediate.first.time).to be_within(0.01).of(t1 + 10)
        expect(intermediate.last.time).to be_within(0.01).of(t1 + 20)
      end

      it 'sets time to nil when start point has no time' do
        wp_no_time = make_waypoint(lat: 48.0, lon: 16.0)
        result = splitter.split([wp_no_time, wp2], 50)
        result[1...-1].each { |pt| expect(pt.time).to be_nil }
      end

      it 'sets time to nil when end point has no time' do
        wp_no_time = make_waypoint(lat: 48.001, lon: 16.0)
        result = splitter.split([wp1, wp_no_time], 50)
        result[1...-1].each { |pt| expect(pt.time).to be_nil }
      end
    end

    context 'with multiple pairs, only some exceeding the limit' do
      # wp1→wp2: ~111 m (> 200 → no split), wp2→wp3: ~1113 m (> 200 → split)
      let(:wp1) { make_waypoint(lat: 48.0,   lon: 16.0) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.0) } # ~111 m
      let(:wp3) { make_waypoint(lat: 48.011, lon: 16.0) } # ~1113 m from wp2

      it 'only splits pairs that exceed the limit' do
        result = splitter.split([wp1, wp2, wp3], 200)
        # wp1→wp2 ~111 m ≤ 200 → no split
        # wp2→wp3 ~1113 m > 200 → ceil(1113/200)=6 segs → 5 intermediate points
        # total: 3 original + 5 intermediate = 8
        expected_count = 3 + 5
        expect(result.length).to eq(expected_count)
        expect(result.first).to eq(wp1)
        expect(result[1]).to eq(wp2)
        expect(result.last).to eq(wp3)
      end
    end

    context 'exact boundary (distance == max_distance)' do
      it 'does not split when distance is clearly within the limit' do
        # ~55 m apart (0.0005 deg lat), max_distance 100 m → no split
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.0005, lon: 16.0)
        result = splitter.split([wp1, wp2], 100)
        expect(result.length).to eq(2)
      end
    end
  end
end
