# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::Transplant::Coordinates do
  # n1, n2, ..., n9 along a line; m1 sits close to n2, m3 close to n8.
  let(:route)       { (1..9).map { |i| [48.0, 16.0 + (i * 0.01)] } }
  let(:transplant)  { [[48.0001, 16.0201], [48.0002, 16.05], [48.0001, 16.0801]] }

  describe '.graft' do
    it 'replaces the matching section with the transplant' do
      expect(described_class.graft(route, transplant)).to eq(
        [[48.0, 16.01], [48.0001, 16.0201], [48.0002, 16.05], [48.0001, 16.0801], [48.0, 16.09]]
      )
    end

    it 'returns the original point objects, not reconstructed coordinates' do
      waypoint_route = route.map { |lat, lon| GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon) }
      waypoint_transplant = transplant.map { |lat, lon| GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon) }

      result = described_class.graft(waypoint_route, waypoint_transplant)

      expect(result[0]).to be(waypoint_route[0])
      expect(result[1..3]).to eq(waypoint_transplant)
      expect(result[4]).to be(waypoint_route[8])
    end

    it 'accepts hashes keyed by lat/lon' do
      hash_route = route.map { |lat, lon| { lat: lat, lon: lon } }
      hash_transplant = transplant.map { |lat, lon| { lat: lat, lon: lon } }

      result = described_class.graft(hash_route, hash_transplant)
      expect(result).to eq([hash_route[0], *hash_transplant, hash_route[8]])
    end

    it 'reads pairs as [lon, lat] when asked to' do
      lon_lat_route = route.map { |lat, lon| [lon, lat] }
      lon_lat_transplant = transplant.map { |lat, lon| [lon, lat] }

      result = described_class.graft(lon_lat_route, lon_lat_transplant, coordinate_order: :lon_lat)
      expect(result).to eq([lon_lat_route[0], *lon_lat_transplant, lon_lat_route[8]])
    end

    it 'raises when the route holds no points' do
      expect { described_class.graft([], transplant) }.to raise_error(ArgumentError, /route holds no points/)
    end

    it 'raises when the transplant holds no points' do
      expect { described_class.graft(route, []) }.to raise_error(ArgumentError, /transplant holds no points/)
    end

    it 'raises when the transplant start/end is too far from the route' do
      far_transplant = [[50.0, 20.0], [50.0, 20.01]]
      expect { described_class.graft(route, far_transplant, tolerance: 25.0) }.to raise_error(ArgumentError, /tolerance/)
    end

    it 'skips the tolerance check when tolerance is nil' do
      # Both far points sit closest to n9 (the point with the least longitude
      # gap), so the whole tail of the route is replaced by the transplant.
      far_transplant = [[50.0, 20.0], [50.0, 20.01]]
      result = described_class.graft(route, far_transplant, tolerance: nil)
      expect(result).to eq([*route[0..7], *far_transplant])
    end

    it 'raises when the transplant end matches before its start on the route' do
      reversed = [transplant.last, transplant.first]
      expect { described_class.graft(route, reversed) }.to raise_error(ArgumentError, /lies before its start/)
    end
  end
end
