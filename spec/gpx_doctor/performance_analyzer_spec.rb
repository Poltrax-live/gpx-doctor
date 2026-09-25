# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::PerformanceAnalyzer do
  subject(:analyzer) { described_class.new }

  def make_waypoint(lat:, lon:, ele: nil, time: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele, time: time)
  end

  describe '#analyze' do
    it 'raises InvalidGpxError when no timestamps are present' do
      points = [
        make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0),
        make_waypoint(lat: 48.01, lon: 16.01, ele: 120.0)
      ]

      expect { analyzer.analyze([points]) }
        .to raise_error(GpxDoctor::InvalidGpxError, /timestamps/)
    end

    it 'returns zeroed time metrics when no valid positive time deltas exist' do
      t = Time.utc(2024, 1, 1, 10, 0, 0)
      points = [
        make_waypoint(lat: 48.0, lon: 16.0, time: t),
        make_waypoint(lat: 48.01, lon: 16.01, time: t)
      ]

      analysis = analyzer.analyze([points])

      expect(analysis[:total_time]).to eq(0)
      expect(analysis[:distance]).to eq(0.0)
      expect(analysis[:avg_speed]).to eq(0.0)
      expect(analysis[:top_speed]).to eq(0.0)
      expect(analysis[:speed_array]).to eq([])
    end

    it 'does not include elevation metrics when no elevation pairs are present' do
      t1 = Time.utc(2024, 1, 1, 10, 0, 0)
      t2 = Time.utc(2024, 1, 1, 10, 5, 0)
      points = [
        make_waypoint(lat: 48.0, lon: 16.0, time: t1),
        make_waypoint(lat: 48.01, lon: 16.01, time: t2)
      ]

      analysis = analyzer.analyze([points])

      expect(analysis).not_to have_key(:ascent)
      expect(analysis).not_to have_key(:descent)
      expect(analysis).not_to have_key(:elevation_change_array)
      expect(analysis).not_to have_key(:top_vertical_speed)
      expect(analysis).not_to have_key(:vertical_speed_array)
    end

    it 'computes ascent, descent and vertical speed metrics from mixed elevation changes' do
      t1 = Time.utc(2024, 1, 1, 10, 0, 0)
      t2 = Time.utc(2024, 1, 1, 10, 5, 0)
      t3 = Time.utc(2024, 1, 1, 10, 10, 0)
      points = [
        make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0, time: t1),
        make_waypoint(lat: 48.01, lon: 16.01, ele: 120.0, time: t2),
        make_waypoint(lat: 48.02, lon: 16.02, ele: 90.0, time: t3)
      ]

      analysis = analyzer.analyze([points])

      expect(analysis[:elevation_change_array]).to eq([20.0, -30.0])
      expect(analysis[:ascent]).to eq(20)
      expect(analysis[:descent]).to eq(30)
      expect(analysis[:vertical_speed_array]).to eq([0.067, -0.1])
      expect(analysis[:top_vertical_speed]).to eq(0.1)
    end

    it 'does not bridge metrics between separate collections' do
      a1 = make_waypoint(lat: 48.0, lon: 16.0, time: Time.utc(2024, 1, 1, 10, 0, 0))
      a2 = make_waypoint(lat: 48.01, lon: 16.01, time: Time.utc(2024, 1, 1, 10, 5, 0))
      b1 = make_waypoint(lat: 49.0, lon: 17.0, time: Time.utc(2024, 1, 1, 12, 0, 0))
      b2 = make_waypoint(lat: 49.01, lon: 17.01, time: Time.utc(2024, 1, 1, 12, 5, 0))

      analysis = analyzer.analyze([[a1, a2], [b1, b2]])

      expect(analysis[:total_time]).to eq(600)
      expect(analysis[:speed_array].length).to eq(2)
    end
  end
end
