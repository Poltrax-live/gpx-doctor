# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::DistanceCalculator do
  def make_waypoint(lat:, lon:)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon)
  end

  describe '.distance' do
    it 'returns 0.0 for identical points' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      expect(described_class.distance(a, a)).to eq(0.0)
    end

    it 'calculates correct distance for a north-south displacement' do
      # 1 degree latitude = ~111_320 m
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 49.0, lon: 16.0)
      expect(described_class.distance(a, b)).to be_within(10).of(111_320.0)
    end

    it 'accounts for latitude when calculating east-west distance' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 48.0, lon: 17.0)
      expected = 111_320.0 * Math.cos(48.0 * Math::PI / 180.0)
      expect(described_class.distance(a, b)).to be_within(10).of(expected)
    end

    it 'is symmetric (distance from a to b equals distance from b to a)' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 48.001, lon: 16.001)
      expect(described_class.distance(a, b)).to be_within(1e-9).of(described_class.distance(b, a))
    end
  end

  describe '.bearing' do
    it 'returns ~0 (north) when moving due north' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 49.0, lon: 16.0)
      expect(described_class.bearing(a, b)).to be_within(0.1).of(0.0)
    end

    it 'returns ~90 (east) when moving due east' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 48.0, lon: 17.0)
      expect(described_class.bearing(a, b)).to be_within(0.1).of(90.0)
    end

    it 'returns ~180 (south) when moving due south' do
      a = make_waypoint(lat: 49.0, lon: 16.0)
      b = make_waypoint(lat: 48.0, lon: 16.0)
      expect(described_class.bearing(a, b)).to be_within(0.1).of(180.0)
    end

    it 'returns ~270 (west) when moving due west' do
      a = make_waypoint(lat: 48.0, lon: 17.0)
      b = make_waypoint(lat: 48.0, lon: 16.0)
      expect(described_class.bearing(a, b)).to be_within(0.1).of(270.0)
    end

    it 'returns a value in [0, 360)' do
      a = make_waypoint(lat: 48.0, lon: 16.0)
      b = make_waypoint(lat: 47.0, lon: 15.0)
      result = described_class.bearing(a, b)
      expect(result).to be >= 0
      expect(result).to be < 360
    end
  end
end
