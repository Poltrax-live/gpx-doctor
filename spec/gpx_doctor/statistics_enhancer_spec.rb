# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::StatisticsEnhancer do
  subject(:enhancer) { described_class.new }

  def make_waypoint(lat:, lon:, ele: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele)
  end

  describe '#enhance' do
    it 'does nothing for nil input' do
      expect { enhancer.enhance(nil) }.not_to raise_error
    end

    it 'does nothing for an empty list' do
      expect { enhancer.enhance([]) }.not_to raise_error
    end

    it 'does nothing for a single waypoint' do
      wp = make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0)
      enhancer.enhance([wp])
      expect(wp.distance_to_next).to be_nil
      expect(wp.elevation_change).to be_nil
      expect(wp.direction).to be_nil
    end

    context 'with two waypoints' do
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.001, ele: 120.0) }

      before { enhancer.enhance([wp1, wp2]) }

      it 'sets distance_to_next on the first point' do
        expect(wp1.distance_to_next).to be_a(Float)
        expect(wp1.distance_to_next).to be > 0
      end

      it 'sets elevation_change on the first point' do
        expect(wp1.elevation_change).to eq(20.0)
      end

      it 'sets direction on the first point' do
        expect(wp1.direction).to be_a(Float)
        expect(wp1.direction).to be >= 0
        expect(wp1.direction).to be < 360
      end

      it 'does not set statistics on the last point' do
        expect(wp2.distance_to_next).to be_nil
        expect(wp2.elevation_change).to be_nil
        expect(wp2.direction).to be_nil
      end
    end

    context 'direction calculations' do
      it 'returns ~0 (north) when moving due north' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 49.0, lon: 16.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.direction).to be_within(0.1).of(0.0)
      end

      it 'returns ~90 (east) when moving due east' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.0, lon: 17.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.direction).to be_within(0.1).of(90.0)
      end

      it 'returns ~180 (south) when moving due south' do
        wp1 = make_waypoint(lat: 49.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.0, lon: 16.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.direction).to be_within(0.1).of(180.0)
      end

      it 'returns ~270 (west) when moving due west' do
        wp1 = make_waypoint(lat: 48.0, lon: 17.0)
        wp2 = make_waypoint(lat: 48.0, lon: 16.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.direction).to be_within(0.1).of(270.0)
      end

      it 'returns ~45 (northeast) for diagonal movement' do
        # Using small deltas so flat-earth is accurate
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        # To get 45 degrees, dlat_m and dlon_m need to be equal.
        # dlat_m = dlat * 111320
        # dlon_m = dlon * 111320 * cos(avg_lat)
        # So dlon = dlat / cos(avg_lat)
        avg_lat_rad = 48.0005 * Math::PI / 180.0
        dlon = 0.001 / Math.cos(avg_lat_rad)
        wp2 = make_waypoint(lat: 48.001, lon: 16.0 + dlon)
        enhancer.enhance([wp1, wp2])
        expect(wp1.direction).to be_within(0.5).of(45.0)
      end
    end

    context 'distance calculations' do
      it 'calculates correct distance for a known north-south displacement' do
        # 1 degree latitude = ~111,320 meters
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 49.0, lon: 16.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.distance_to_next).to be_within(10).of(111_320.0)
      end

      it 'calculates distance for east-west movement accounting for latitude' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.0, lon: 17.0)
        enhancer.enhance([wp1, wp2])
        expected = 111_320.0 * Math.cos(48.0 * Math::PI / 180.0)
        expect(wp1.distance_to_next).to be_within(10).of(expected)
      end

      it 'returns 0 distance when points are identical' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.0, lon: 16.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.distance_to_next).to eq(0.0)
      end
    end

    context 'elevation change' do
      it 'calculates positive elevation change (ascent)' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0)
        wp2 = make_waypoint(lat: 48.001, lon: 16.001, ele: 200.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.elevation_change).to eq(100.0)
      end

      it 'calculates negative elevation change (descent)' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0, ele: 200.0)
        wp2 = make_waypoint(lat: 48.001, lon: 16.001, ele: 100.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.elevation_change).to eq(-100.0)
      end

      it 'returns nil when current point has no elevation' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.001, lon: 16.001, ele: 100.0)
        enhancer.enhance([wp1, wp2])
        expect(wp1.elevation_change).to be_nil
      end

      it 'returns nil when next point has no elevation' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0)
        wp2 = make_waypoint(lat: 48.001, lon: 16.001)
        enhancer.enhance([wp1, wp2])
        expect(wp1.elevation_change).to be_nil
      end

      it 'returns nil when both points have no elevation' do
        wp1 = make_waypoint(lat: 48.0, lon: 16.0)
        wp2 = make_waypoint(lat: 48.001, lon: 16.001)
        enhancer.enhance([wp1, wp2])
        expect(wp1.elevation_change).to be_nil
      end
    end

    context 'with multiple waypoints' do
      it 'enhances all but the last waypoint' do
        wps = [
          make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0),
          make_waypoint(lat: 48.001, lon: 16.001, ele: 110.0),
          make_waypoint(lat: 48.002, lon: 16.002, ele: 105.0),
          make_waypoint(lat: 48.003, lon: 16.003, ele: 120.0)
        ]
        enhancer.enhance(wps)

        wps[0...-1].each do |wp|
          expect(wp.distance_to_next).to be_a(Float)
          expect(wp.distance_to_next).to be > 0
          expect(wp.elevation_change).to be_a(Float)
          expect(wp.direction).to be_a(Float)
        end

        expect(wps.last.distance_to_next).to be_nil
        expect(wps.last.elevation_change).to be_nil
        expect(wps.last.direction).to be_nil
      end
    end
  end
end
