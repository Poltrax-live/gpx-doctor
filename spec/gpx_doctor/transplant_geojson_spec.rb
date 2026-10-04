# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe GpxDoctor::Transplant::GeoJson do
  # n1, n2, ..., n9 along a line; m1 sits close to n2, m3 close to n8.
  let(:route_coordinates)       { (1..9).map { |i| [16.0 + (i * 0.01), 48.0] } }
  let(:transplant_coordinates)  { [[16.0201, 48.0001], [16.05, 48.0002], [16.0801, 48.0001]] }
  let(:route)      { { type: 'LineString', coordinates: route_coordinates } }
  let(:transplant) { { type: 'LineString', coordinates: transplant_coordinates } }

  describe '.graft' do
    it 'returns a Feature wrapping the spliced LineString' do
      result = described_class.graft(route, transplant)

      expect(result[:type]).to eq('Feature')
      expect(result[:geometry][:type]).to eq('LineString')
      expect(result[:geometry][:coordinates]).to eq(
        [[16.01, 48.0], *transplant_coordinates, [16.09, 48.0]]
      )
    end

    it 'accepts a Feature wrapping a LineString' do
      feature = { type: 'Feature', geometry: route }
      result = described_class.graft(feature, transplant)
      expect(result[:geometry][:coordinates].first).to eq([16.01, 48.0])
    end

    it 'accepts a FeatureCollection with a single LineString feature (ignoring POI points)' do
      collection = {
        type: 'FeatureCollection',
        features: [
          { type: 'Feature', geometry: { type: 'Point', coordinates: [16.0, 48.0] } },
          { type: 'Feature', geometry: route }
        ]
      }
      result = described_class.graft(collection, transplant)
      expect(result[:geometry][:coordinates].first).to eq([16.01, 48.0])
    end

    it 'accepts JSON strings' do
      result = described_class.graft(JSON.generate(route), JSON.generate(transplant))
      expect(result[:geometry][:coordinates]).to eq(
        [[16.01, 48.0], *transplant_coordinates, [16.09, 48.0]]
      )
    end

    it 'preserves elevation as the third coordinate element' do
      elevated_route = { type: 'LineString', coordinates: route_coordinates.map { |lon, lat| [lon, lat, 100.0] } }
      result = described_class.graft(elevated_route, transplant)
      expect(result[:geometry][:coordinates].first).to eq([16.01, 48.0, 100.0])
    end

    it 'raises when the document holds no positions' do
      empty = { type: 'LineString', coordinates: [] }
      expect { described_class.graft(empty, transplant) }.to raise_error(ArgumentError, /route GeoJSON holds no positions/)
    end

    it 'raises when a FeatureCollection holds more than one LineString feature' do
      collection = {
        type: 'FeatureCollection',
        features: [
          { type: 'Feature', geometry: route },
          { type: 'Feature', geometry: transplant }
        ]
      }
      expect { described_class.graft(collection, transplant) }.to raise_error(ArgumentError, /exactly one LineString/)
    end

    it 'raises when the transplant start/end is too far from the route' do
      far_transplant = { type: 'LineString', coordinates: [[20.0, 50.0], [20.01, 50.0]] }
      expect { described_class.graft(route, far_transplant, tolerance: 25.0) }.to raise_error(ArgumentError, /tolerance/)
    end
  end
end
