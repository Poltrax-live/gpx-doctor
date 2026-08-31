# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::PointLabeler do
  subject(:labeler) { described_class.new }

  LABELER_METERS_PER_DEG = GpxDoctor::DistanceCalculator::METERS_PER_DEGREE_LAT
  LABELER_KM_PER_DEG = LABELER_METERS_PER_DEG / 1000.0

  def make_waypoint(lat:, lon: 16.0, ele: nil, time: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele, time: time)
  end

  # Builds points spaced along a north/south line so that cumulative
  # distance in km is simply |delta_lat| * LABELER_KM_PER_DEG, one entry per
  # requested cumulative distance (in km) from the start.
  def points_at_distances(distances_km, ele: nil)
    distances_km.map { |d| make_waypoint(lat: 48.0 + d / LABELER_KM_PER_DEG, ele: ele && ele + d) }
  end

  describe '#label' do
    it 'returns nil input unchanged' do
      expect(labeler.label(nil, 1.0)).to be_nil
    end

    it 'returns the array unchanged when it has fewer than two points' do
      pts = [make_waypoint(lat: 48.0)]
      expect(labeler.label(pts, 1.0)).to eq(pts)
    end

    it 'returns the array unchanged when label_interval is nil' do
      pts = points_at_distances([0.0, 2.0])
      expect(labeler.label(pts, nil)).to eq(pts)
    end

    it 'returns the array unchanged when label_interval is zero' do
      pts = points_at_distances([0.0, 2.0])
      expect(labeler.label(pts, 0)).to eq(pts)
    end

    it 'returns the array unchanged when label_interval is negative' do
      pts = points_at_distances([0.0, 2.0])
      expect(labeler.label(pts, -1.0)).to eq(pts)
    end

    context 'with a point at 0.9 km and 1.2 km and label_interval 1.0' do
      let(:pts) { points_at_distances([0.0, 0.9, 1.2]) }

      it 'inserts one extra point at the 1.0 mark' do
        result = labeler.label(pts, 1.0)
        expect(result.length).to eq(pts.length + 1)
      end

      it 'places the new point between the 0.9 km and 1.2 km points' do
        result = labeler.label(pts, 1.0)
        expect(result[0]).to eq(pts[0])
        expect(result[1]).to eq(pts[1])
        expect(result[3]).to eq(pts[2])
        inserted = result[2]
        expect(inserted.lat).to be > pts[1].lat
        expect(inserted.lat).to be < pts[2].lat
      end

      it 'sets the label field of the inserted point to the interval mark' do
        result = labeler.label(pts, 1.0)
        expect(result[2].label).to be_within(1e-9).of(1.0)
      end

      it 'leaves the label field of the original points nil' do
        result = labeler.label(pts, 1.0)
        expect(result[0].label).to be_nil
        expect(result[1].label).to be_nil
        expect(result[3].label).to be_nil
      end

      it 'interpolates elevation and does not mutate the original array' do
        pts_with_ele = points_at_distances([0.0, 0.9, 1.2], ele: 100.0)
        result = labeler.label(pts_with_ele, 1.0)
        expect(result.length).to eq(4)
        expect(result[2].ele).to be_within(1e-6).of(100.0 + 1.0)
        expect(pts_with_ele.length).to eq(3)
      end
    end

    it 'inserts a labelled point at every interval multiple within a single long segment' do
      pts = points_at_distances([0.0, 5.0])
      result = labeler.label(pts, 1.0)
      # Marks at 1.0, 2.0, 3.0, 4.0 (5.0 coincides with the last point)
      expect(result.length).to eq(2 + 4)
      labels = result.map(&:label).compact
      expect(labels).to eq([1.0, 2.0, 3.0, 4.0])
    end

    it 'does not insert a duplicate point when a mark coincides with an existing point' do
      pts = points_at_distances([0.0, 1.0, 2.0])
      result = labeler.label(pts, 1.0)
      expect(result.length).to eq(pts.length)
      expect(result.map(&:label)).to all(be_nil)
    end

    it 'advances past consecutive marks that each coincide with an existing point' do
      pts = points_at_distances([0.0, 1.0, 2.0, 3.0])
      result = labeler.label(pts, 1.0)
      expect(result.length).to eq(pts.length)
      expect(result.map(&:label)).to all(be_nil)
    end

    it 'does not insert any point when label_interval exceeds the total distance' do
      pts = points_at_distances([0.0, 0.5])
      result = labeler.label(pts, 10.0)
      expect(result).to eq(pts)
    end

    it 'respects the configured unit_system (miles for :imperial)' do
      GpxDoctor.configure { |c| c.unit_system = :imperial }
      # 1 mile = 1.609344 km; place points at 0 and 2 miles worth of km distance
      miles_per_km = GpxDoctor::UnitConverter::KILOMETERS_TO_MILES
      total_km = 2.0 / miles_per_km
      pts = points_at_distances([0.0, total_km])

      result = labeler.label(pts, 1.0)
      expect(result.length).to eq(3)
      expect(result[1].label).to be_within(1e-6).of(1.0)
    end

    context 'when points already carry a precomputed cumulative_distance' do
      it 'reuses the precomputed values instead of recalculating from lat/lon' do
        # Geographically these points are ~0.9 km and ~1.2 km apart, which would
        # normally place a single label at the 1.0 mark. Overriding
        # cumulative_distance with very different values (0, 2, 4) proves the
        # overridden values — not the real geographic distance — are used.
        pts = points_at_distances([0.0, 0.9, 1.2])
        pts[0].cumulative_distance = 0.0
        pts[1].cumulative_distance = 2.0
        pts[2].cumulative_distance = 4.0

        result = labeler.label(pts, 1.0)
        # Marks at 1.0 (between pts[0] and pts[1]) and 3.0 (between pts[1] and pts[2])
        expect(result.length).to eq(5)
        labels = result.map(&:label).compact
        expect(labels).to eq([1.0, 3.0])
      end

      it 'does not mutate the precomputed cumulative_distance values' do
        pts = points_at_distances([0.0, 1.0, 2.0])
        pts[0].cumulative_distance = 0.0
        pts[1].cumulative_distance = 1.0
        pts[2].cumulative_distance = 2.0

        labeler.label(pts, 1.0)
        expect(pts.map(&:cumulative_distance)).to eq([0.0, 1.0, 2.0])
      end

      it 'falls back to recalculating when only some points have cumulative_distance set' do
        # pts[2] is missing cumulative_distance — treat the whole set as not
        # precomputed rather than silently treating the missing value as nil
        # during interpolation.
        pts = points_at_distances([0.0, 0.9, 1.2])
        pts[0].cumulative_distance = 0.0
        pts[1].cumulative_distance = 0.9

        result = labeler.label(pts, 1.0)
        expect(result.length).to eq(4)
        expect(result[2].label).to be_within(1e-6).of(1.0)
      end
    end
  end
end
