# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::Similarity, 'comparing coordinates' do
  # sample.gpx holds a route from [48.21, 16.36] to [48.22, 16.37] and a track
  # segment from [48.23, 16.38] to [48.24, 16.39].
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:on_path)      { [48.21, 16.36] }
  let(:off_path)     { [49.21, 17.36] }

  describe '.compare' do
    it 'accepts an array of [lat, lon] pairs' do
      expect(described_class.compare(fixture_path, [on_path, [48.22, 16.37]])).to eq(1.0)
    end

    it 'accepts a single coordinate pair' do
      expect(described_class.compare(fixture_path, on_path)).to eq(1.0)
    end

    it 'reads pairs as [lon, lat] when asked to' do
      expect(described_class.compare(fixture_path, [[16.36, 48.21]], coordinate_order: :lon_lat)).to eq(1.0)
    end

    it 'accepts hashes keyed by lat/lon, latitude/longitude or x/y' do
      coordinates = [
        { lat: 48.21, lon: 16.36 },
        { 'latitude' => 48.22, 'longitude' => 16.37 },
        { x: 16.38, y: 48.23 }
      ]
      expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
    end

    it 'accepts waypoints and anything else answering to lat and lon' do
      waypoint = GpxDoctor::Models::Waypoint.new(lat: 48.21, lon: 16.36)
      expect(described_class.compare(fixture_path, [waypoint])).to eq(1.0)
    end

    it 'accepts PostGIS WKT geometries' do
      expect(described_class.compare(fixture_path, 'SRID=4326;POINT(16.36 48.21)')).to eq(1.0)
      expect(described_class.compare(fixture_path, 'LINESTRING(16.36 48.21, 16.37 48.22)')).to eq(1.0)
      expect(described_class.compare(fixture_path, 'MULTIPOINT((16.36 48.21), (17.36 49.21))')).to eq(0.5)
    end

    it 'counts a coordinate lying between two reference points' do
      # Halfway along the track segment: ~650 m from either of its points, yet
      # exactly on the path they describe.
      expect(described_class.compare(fixture_path, [[48.235, 16.385]])).to eq(1.0)
    end

    it 'returns 0.0 when nothing follows the path' do
      expect(described_class.compare(fixture_path, [off_path, [49.22, 17.37]])).to eq(0.0)
    end

    it 'rounds the fraction of matching points' do
      expect(described_class.compare(fixture_path, [on_path, [48.22, 16.37], off_path])).to eq(0.6667)
    end
  end

  describe 'sample_interval' do
    # The straight line from the start of the route to the end of the track
    # runs over the gap between the two, which is not part of the path.
    let(:coordinates) { [[48.21, 16.36], [48.24, 16.39]] }

    it 'only looks at the given points by default' do
      expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
    end

    it 'also looks between the given points when asked to' do
      score = described_class.compare(fixture_path, coordinates, sample_interval: 50)
      expect(score).to be > 0.5
      expect(score).to be < 0.8
    end

    it 'keeps a full match when the sampled line follows the path' do
      on_segment = [[48.23, 16.38], [48.24, 16.39]]
      expect(described_class.compare(fixture_path, on_segment, sample_interval: 50)).to eq(1.0)
    end
  end

  describe 'point order' do
    # A square lap of roughly 1.1 km a side, closed by repeating its first point
    # the way a recorded loop does.
    let(:circular_route) do
      [[48.20, 16.30], [48.21, 16.30], [48.21, 16.31], [48.20, 16.31], [48.20, 16.30]]
    end

    it 'returns 1.0 for a reversed array of coordinates' do
      coordinates = [[48.21, 16.36], [48.215, 16.365], [48.22, 16.37]]
      expect(described_class.compare(fixture_path, coordinates.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'ignores the order the compared points come in' do
      coordinates = [[48.21, 16.36], [48.24, 16.39], [48.23, 16.38], [48.22, 16.37]]
      expect(described_class.compare(fixture_path, coordinates)).to eq(1.0)
    end

    it 'returns 1.0 for a track that doubles back on itself' do
      there = [[48.23, 16.38], [48.235, 16.385], [48.24, 16.39]]
      there_and_back = there + there[0..-2].reverse
      expect(described_class.compare(fixture_path, there_and_back, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route ridden the other way round' do
      expect(described_class.compare(circular_route, circular_route.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route started at another of its points' do
      rotated = circular_route[0..-2].rotate(2)
      rotated += [rotated.first]

      expect(described_class.compare(circular_route, rotated, sample_interval: 50)).to eq(1.0)
      expect(described_class.compare(rotated, circular_route, sample_interval: 50)).to eq(1.0)
    end

    it 'returns 1.0 for a circular route started between two of its points' do
      # Halfway up the first side of the lap, so the start is not one of the
      # recorded points at all.
      halfway = [48.205, 16.30]
      rotated = [halfway] + circular_route[1..-1] + [halfway]

      expect(described_class.compare(circular_route, rotated, sample_interval: 50)).to eq(1.0)
      expect(described_class.compare(circular_route, rotated.reverse, sample_interval: 50)).to eq(1.0)
    end

    it 'still misses a circular route that runs beside the lap' do
      beside = circular_route.reverse.map { |lat, lon| [lat, lon + 0.0015] } # ~110 m east
      expect(described_class.compare(circular_route, beside, sample_interval: 50)).to be < 0.5
    end
  end

  describe 'invalid input' do
    it 'raises for an unsupported source' do
      expect { described_class.compare(fixture_path, 'not a track') }
        .to raise_error(ArgumentError, /unsupported source/)
    end

    it 'raises for an unsupported coordinate' do
      expect { described_class.compare(fixture_path, [{ foo: 1 }]) }
        .to raise_error(ArgumentError, /latitude and a longitude/)
    end

    it 'raises when there is nothing to compare' do
      expect { described_class.compare(fixture_path, []) }
        .to raise_error(ArgumentError, /no points to compare/)
    end

    it 'raises when a latitude is out of range' do
      expect { described_class.compare(fixture_path, [[116.36, 48.21]]) }
        .to raise_error(ArgumentError, /out of range/)
    end

    it 'raises for a tolerance that is not a positive number' do
      expect { described_class.compare(fixture_path, [on_path], tolerance: 0) }
        .to raise_error(ArgumentError, /tolerance must be positive/)
      expect { described_class.compare(fixture_path, [on_path], tolerance: nil) }
        .to raise_error(ArgumentError, /tolerance must be a number/)
    end

    it 'raises for an unknown coordinate order' do
      expect { described_class.compare(fixture_path, [on_path], coordinate_order: :whatever) }
        .to raise_error(ArgumentError, /coordinate_order/)
    end
  end
end
