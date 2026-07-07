# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::CumulativeDistanceEnhancer do
  subject(:enhancer) { described_class.new }

  def make_waypoint(lat:, lon:)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon)
  end

  describe '#enhance' do
    it 'does nothing for nil input' do
      expect { enhancer.enhance(nil) }.not_to raise_error
    end

    it 'does nothing for an empty list' do
      expect { enhancer.enhance([]) }.not_to raise_error
    end

    it 'sets cumulative_distance to 0.0 for a single waypoint' do
      wp = make_waypoint(lat: 48.0, lon: 16.0)
      enhancer.enhance([wp])
      expect(wp.cumulative_distance).to eq(0.0)
    end

    context 'with two waypoints' do
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0) }
      let(:wp2) { make_waypoint(lat: 48.001, lon: 16.001) }

      before { enhancer.enhance([wp1, wp2]) }

      it 'sets cumulative_distance to 0.0 for the first point' do
        expect(wp1.cumulative_distance).to eq(0.0)
      end

      it 'sets cumulative_distance on the second point based on distance from first' do
        expect(wp2.cumulative_distance).to be_a(Float)
        expect(wp2.cumulative_distance).to be > 0
      end
    end

    context 'with three waypoints in a straight line north' do
      # 1 degree latitude ≈ 111,320 meters = 111.32 kilometers
      let(:wp1) { make_waypoint(lat: 48.0, lon: 16.0) }
      let(:wp2) { make_waypoint(lat: 49.0, lon: 16.0) }
      let(:wp3) { make_waypoint(lat: 50.0, lon: 16.0) }

      before { enhancer.enhance([wp1, wp2, wp3]) }

      it 'sets cumulative_distance correctly for each point in kilometers' do
        expect(wp1.cumulative_distance).to eq(0.0)
        expect(wp2.cumulative_distance).to be_within(0.01).of(111.32)
        expect(wp3.cumulative_distance).to be_within(0.02).of(222.64)
      end

      it 'accumulates distances correctly' do
        expect(wp3.cumulative_distance).to be_within(0.001).of(wp2.cumulative_distance * 2)
      end
    end

    context 'with multiple waypoints' do
      let(:waypoints) do
        [
          make_waypoint(lat: 48.0, lon: 16.0),
          make_waypoint(lat: 48.001, lon: 16.001),
          make_waypoint(lat: 48.002, lon: 16.002),
          make_waypoint(lat: 48.003, lon: 16.003)
        ]
      end

      before { enhancer.enhance(waypoints) }

      it 'ensures cumulative distances are monotonically increasing' do
        distances = waypoints.map(&:cumulative_distance)
        expect(distances).to eq(distances.sort)
      end

      it 'sets the first waypoint cumulative_distance to 0' do
        expect(waypoints.first.cumulative_distance).to eq(0.0)
      end

      it 'ensures each subsequent waypoint has a greater cumulative_distance' do
        waypoints.each_cons(2) do |prev, curr|
          expect(curr.cumulative_distance).to be > prev.cumulative_distance
        end
      end
    end
  end
end
