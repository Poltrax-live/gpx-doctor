# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::Parser do
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:fixture_xml)  { File.read(fixture_path) }
  let(:result)       { described_class.parse(fixture_path) }
  let(:result_from_string) { described_class.parse_string(fixture_xml) }

  describe '.parse' do
    it 'returns a Result object' do
      expect(result).to be_a(GpxDoctor::Parser::Result)
    end

    it 'produces the same output as parse_string' do
      expect(result.points.length).to eq(result_from_string.points.length)
    end
  end

  describe '#waypoints' do
    it 'returns the top-level wpt elements' do
      expect(result.waypoints.length).to eq(1)
    end

    it 'has correct lat/lon' do
      wpt = result.waypoints.first
      expect(wpt.lat).to be_within(0.0001).of(48.2093723)
      expect(wpt.lon).to be_within(0.0001).of(16.356099)
    end

    it 'has elevation' do
      expect(result.waypoints.first.ele).to eq(160.0)
    end

    it 'has name and desc' do
      wpt = result.waypoints.first
      expect(wpt.name).to eq('Waypoint 1')
      expect(wpt.desc).to eq('A standalone waypoint')
    end

    it 'has time as a Time object' do
      expect(result.waypoints.first.time).to be_a(Time)
    end
  end

  describe '#routes' do
    it 'returns route objects' do
      expect(result.routes.length).to eq(1)
    end

    it 'has route name' do
      expect(result.routes.first.name).to eq('Route 1')
    end

    it 'has route points' do
      expect(result.routes.first.points.length).to eq(2)
    end

    it 'has correct route point coordinates' do
      pt = result.routes.first.points.first
      expect(pt.lat).to be_within(0.0001).of(48.21)
      expect(pt.lon).to be_within(0.0001).of(16.36)
      expect(pt.ele).to eq(155.0)
    end
  end

  describe '#tracks' do
    it 'returns track objects' do
      expect(result.tracks.length).to eq(1)
    end

    it 'has track name' do
      expect(result.tracks.first.name).to eq('Track 1')
    end

    it 'has segments' do
      expect(result.tracks.first.segments.length).to eq(1)
    end

    it 'has track points in segment' do
      expect(result.tracks.first.segments.first.points.length).to eq(2)
    end

    it 'exposes all track points via #points' do
      expect(result.tracks.first.points.length).to eq(2)
    end

    it 'has correct track point coordinates' do
      pt = result.tracks.first.points.first
      expect(pt.lat).to be_within(0.0001).of(48.23)
      expect(pt.lon).to be_within(0.0001).of(16.38)
      expect(pt.ele).to eq(170.0)
    end
  end

  describe '#points' do
    it 'contains all geographic points (wpt + rtept + trkpt)' do
      # 1 wpt + 2 rtept + 2 trkpt = 5
      expect(result.points.length).to eq(5)
    end

    it 'contains Waypoint objects' do
      expect(result.points).to all(be_a(GpxDoctor::Models::Waypoint))
    end
  end

  describe '#metadata' do
    subject(:meta) { result.metadata }

    it 'is a Metadata object' do
      expect(meta).to be_a(GpxDoctor::Models::Metadata)
    end

    it 'has name' do
      expect(meta.name).to eq('Sample GPX')
    end

    it 'has desc' do
      expect(meta.desc).to eq('A sample GPX file for testing')
    end

    it 'has keywords' do
      expect(meta.keywords).to eq('test, sample, gpx')
    end

    it 'has time as a Time object' do
      expect(meta.time).to be_a(Time)
    end

    it 'has links' do
      expect(meta.links.length).to eq(1)
      expect(meta.links.first.href).to eq('https://example.com/gpx')
      expect(meta.links.first.text).to eq('Source')
    end

    describe 'author' do
      subject(:author) { meta.author }

      it 'is a Person' do
        expect(author).to be_a(GpxDoctor::Models::Person)
      end

      it 'has name' do
        expect(author.name).to eq('Jane Doe')
      end

      it 'has email' do
        expect(author.email).to be_a(GpxDoctor::Models::Email)
        expect(author.email.to_s).to eq('jane@example.com')
      end

      it 'has link' do
        expect(author.link).to be_a(GpxDoctor::Models::Link)
        expect(author.link.href).to eq('https://example.com/jane')
      end
    end

    describe 'copyright' do
      subject(:copyright) { meta.copyright }

      it 'is a Copyright' do
        expect(copyright).to be_a(GpxDoctor::Models::Copyright)
      end

      it 'has author' do
        expect(copyright.author).to eq('Jane Doe')
      end

      it 'has year' do
        expect(copyright.year).to eq('2024')
      end

      it 'has license' do
        expect(copyright.license).to eq('https://creativecommons.org/licenses/by/4.0/')
      end
    end

    describe 'bounds' do
      subject(:bounds) { meta.bounds }

      it 'is a Bounds' do
        expect(bounds).to be_a(GpxDoctor::Models::Bounds)
      end

      it 'has correct values' do
        expect(bounds.minlat).to eq(48.0)
        expect(bounds.minlon).to eq(16.0)
        expect(bounds.maxlat).to eq(49.0)
        expect(bounds.maxlon).to eq(17.0)
      end
    end
  end

  describe 'Waypoint#to_h' do
    subject(:wpt) { result.waypoints.first }

    it 'includes lat, lon, ele' do
      h = wpt.to_h
      expect(h[:lat]).to be_a(Float)
      expect(h[:lon]).to be_a(Float)
      expect(h[:ele]).to eq(160.0)
    end

    it 'excludes nil fields' do
      h = wpt.to_h
      expect(h.keys).not_to include(:magvar)
    end

    it 'includes name' do
      expect(wpt.to_h[:name]).to eq('Waypoint 1')
    end
  end

  # -------------------------------------------------------------------
  # Fixture: gory.gpx  (GPX 1.1 — ridewithgps route with metadata)
  # -------------------------------------------------------------------
  context 'with gory.gpx fixture' do
    let(:gory_path)   { File.expand_path('../fixtures/gory.gpx', __dir__) }
    let(:gory_result) { described_class.parse(gory_path) }

    it 'parses without errors' do
      expect(gory_result).to be_a(GpxDoctor::Parser::Result)
    end

    it 'has no waypoints or routes' do
      expect(gory_result.waypoints).to be_empty
      expect(gory_result.routes).to be_empty
    end

    it 'has one track' do
      expect(gory_result.tracks.length).to eq(1)
    end

    it 'has the correct track name' do
      expect(gory_result.tracks.first.name).to eq('PBT Gory 25 bjazd1')
    end

    it 'has one segment with 10_636 track points' do
      track = gory_result.tracks.first
      expect(track.segments.length).to eq(1)
      expect(track.points.length).to eq(10_636)
    end

    it 'has correct first track point coordinates' do
      pt = gory_result.tracks.first.points.first
      expect(pt.lat).to be_within(0.0001).of(49.560812)
      expect(pt.lon).to be_within(0.0001).of(22.214311)
      expect(pt.ele).to be_within(0.1).of(286.2)
    end

    it 'has correct last track point coordinates' do
      pt = gory_result.tracks.first.points.last
      expect(pt.lat).to be_within(0.0001).of(49.679316)
      expect(pt.lon).to be_within(0.0001).of(19.201696)
      expect(pt.ele).to be_within(0.1).of(354.8)
    end

    it 'reports total points equal to track points' do
      expect(gory_result.points.length).to eq(10_636)
    end

    describe 'metadata' do
      subject(:meta) { gory_result.metadata }

      it 'is present' do
        expect(meta).to be_a(GpxDoctor::Models::Metadata)
      end

      it 'has name' do
        expect(meta.name).to eq('PBT Gory 25 bjazd1')
      end

      it 'has time' do
        expect(meta.time).to be_a(Time)
        expect(meta.time.utc.year).to eq(2025)
      end

      it 'has a link' do
        expect(meta.links.length).to eq(1)
        expect(meta.links.first.href).to eq('https://ridewithgps.com/routes/51348715')
        expect(meta.links.first.text).to eq('PBT Gory 25 bjazd1')
      end
    end
  end

  # -------------------------------------------------------------------
  # Fixture: aus.gpx  (GPX 1.1 — Strava export with timed track points)
  # -------------------------------------------------------------------
  context 'with aus.gpx fixture' do
    let(:aus_path)   { File.expand_path('../fixtures/aus.gpx', __dir__) }
    let(:aus_result) { described_class.parse(aus_path) }

    it 'parses without errors' do
      expect(aus_result).to be_a(GpxDoctor::Parser::Result)
    end

    it 'has no waypoints or routes' do
      expect(aus_result.waypoints).to be_empty
      expect(aus_result.routes).to be_empty
    end

    it 'has one track named Morning Hike' do
      expect(aus_result.tracks.length).to eq(1)
      expect(aus_result.tracks.first.name).to eq('Morning Hike')
    end

    it 'has one segment with 12_954 track points' do
      track = aus_result.tracks.first
      expect(track.segments.length).to eq(1)
      expect(track.points.length).to eq(12_954)
    end

    it 'has correct first track point coordinates and time' do
      pt = aus_result.tracks.first.points.first
      expect(pt.lat).to be_within(0.0001).of(-33.799143)
      expect(pt.lon).to be_within(0.0001).of(151.283918)
      expect(pt.ele).to be_within(0.1).of(3.6)
      expect(pt.time).to be_a(Time)
      expect(pt.time.utc.year).to eq(2021)
    end

    it 'has correct last track point coordinates' do
      pt = aus_result.tracks.first.points.last
      expect(pt.lat).to be_within(0.0001).of(-33.600483)
      expect(pt.lon).to be_within(0.0001).of(151.125633)
      expect(pt.ele).to be_within(0.1).of(1.6)
    end

    it 'reports total points equal to track points' do
      expect(aus_result.points.length).to eq(12_954)
    end

    describe 'metadata' do
      subject(:meta) { aus_result.metadata }

      it 'is present' do
        expect(meta).to be_a(GpxDoctor::Models::Metadata)
      end

      it 'has time' do
        expect(meta.time).to be_a(Time)
        expect(meta.time.utc.year).to eq(2021)
      end

      it 'has no name' do
        expect(meta.name).to be_nil.or eq('')
      end
    end
  end

  # -------------------------------------------------------------------
  # Fixture: 3hunt.gpx  (GPX 1.0 — different namespace)
  # The parser only recognises the GPX 1.1 namespace, so the file
  # should still parse without error but yield no elements.
  # -------------------------------------------------------------------
  context 'with 3hunt.gpx fixture (GPX 1.0)' do
    let(:hunt_path)   { File.expand_path('../fixtures/3hunt.gpx', __dir__) }
    let(:hunt_result) { described_class.parse(hunt_path) }

    it 'parses without raising an error' do
      expect { hunt_result }.not_to raise_error
    end

    it 'returns a Result object' do
      expect(hunt_result).to be_a(GpxDoctor::Parser::Result)
    end

    it 'returns empty collections for a GPX 1.0 file' do
      expect(hunt_result.waypoints).to be_empty
      expect(hunt_result.routes).to be_empty
      expect(hunt_result.tracks).to be_empty
      expect(hunt_result.points).to be_empty
    end

    it 'has no metadata' do
      expect(hunt_result.metadata).to be_nil
    end
  end

  # -------------------------------------------------------------------
  # Elevation enhancement integration
  # -------------------------------------------------------------------
  context 'with elevation server configured and enhance_elevation: true' do
    let(:gpx_without_ele) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <wpt lat="48.2093723" lon="16.356099">
            <name>No Elevation</name>
          </wpt>
          <wpt lat="49.0" lon="17.0">
            <ele>500.0</ele>
            <name>Has Elevation</name>
          </wpt>
          <trk>
            <name>Test Track</name>
            <trkseg>
              <trkpt lat="50.0" lon="18.0"/>
            </trkseg>
          </trk>
        </gpx>
      XML
    end

    before do
      GpxDoctor.configure do |c|
        c.elevation_server     = true
        c.elevation_server_url = 'http://localhost:19292'
      end

      response_body = {
        'results' => [
          { 'latitude' => 48.2093723, 'longitude' => 16.356099, 'elevation' => 171.0 },
          { 'latitude' => 50.0, 'longitude' => 18.0, 'elevation' => 320.5 }
        ]
      }.to_json

      fake_response = instance_double(Net::HTTPOK, body: response_body, code: '200')
      allow(fake_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)
    end

    it 'enhances points without elevation from the elevation server' do
      result = described_class.parse_string(gpx_without_ele, params: { enhance_elevation: true })

      wpt_enhanced = result.waypoints.find { |w| w.name == 'No Elevation' }
      expect(wpt_enhanced.ele).to eq(171.0)
    end

    it 'does not overwrite existing elevation values' do
      result = described_class.parse_string(gpx_without_ele, params: { enhance_elevation: true })

      wpt_existing = result.waypoints.find { |w| w.name == 'Has Elevation' }
      expect(wpt_existing.ele).to eq(500.0)
    end

    it 'enhances track points without elevation' do
      result = described_class.parse_string(gpx_without_ele, params: { enhance_elevation: true })

      trkpt = result.tracks.first.points.first
      expect(trkpt.ele).to eq(320.5)
    end
  end

  context 'without enhance_elevation param' do
    let(:gpx_without_ele) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <wpt lat="48.0" lon="16.0">
            <name>No Elevation</name>
          </wpt>
        </gpx>
      XML
    end

    it 'does not fetch elevation data even when server is configured' do
      GpxDoctor.configure do |c|
        c.elevation_server     = true
        c.elevation_server_url = 'http://localhost:19292'
      end

      expect_any_instance_of(GpxDoctor::ElevationClient).not_to receive(:enhance)

      result = described_class.parse_string(gpx_without_ele)
      expect(result.waypoints.first.ele).to be_nil
    end
  end

  # -------------------------------------------------------------------
  # Statistics enhancement integration
  # -------------------------------------------------------------------
  context 'with statistics enabled' do
    it 'enhances route points with statistics' do
      result = described_class.parse(fixture_path, params: { segment_statistics: true })
      route_pts = result.routes.first.points

      expect(route_pts.first.distance_to_next).to be_a(Float)
      expect(route_pts.first.distance_to_next).to be > 0
      expect(route_pts.first.elevation_change).to eq(7.0) # 162.0 - 155.0
      expect(route_pts.first.direction).to be_a(Float)

      # Last point has no statistics
      expect(route_pts.last.distance_to_next).to be_nil
    end

    it 'enhances track segment points with statistics' do
      result = described_class.parse(fixture_path, params: { segment_statistics: true })
      track_pts = result.tracks.first.segments.first.points

      expect(track_pts.first.distance_to_next).to be_a(Float)
      expect(track_pts.first.distance_to_next).to be > 0
      expect(track_pts.first.elevation_change).to eq(5.0) # 175.0 - 170.0
      expect(track_pts.first.direction).to be_a(Float)

      expect(track_pts.last.distance_to_next).to be_nil
    end

    it 'does not enhance standalone waypoints' do
      result = described_class.parse(fixture_path, params: { segment_statistics: true })
      wpt = result.waypoints.first
      expect(wpt.distance_to_next).to be_nil
    end

    it 'includes statistics in to_h' do
      result = described_class.parse(fixture_path, params: { segment_statistics: true })
      h = result.routes.first.points.first.to_h
      expect(h).to have_key(:distance_to_next)
      expect(h).to have_key(:elevation_change)
      expect(h).to have_key(:direction)
    end

    it 'works with parse_string' do
      result = described_class.parse_string(fixture_xml, params: { segment_statistics: true })
      route_pts = result.routes.first.points

      expect(route_pts.first.distance_to_next).to be_a(Float)
      expect(route_pts.first.distance_to_next).to be > 0
    end
  end

  context 'with statistics disabled (default)' do
    it 'does not add statistics to points' do
      result = described_class.parse(fixture_path)
      route_pts = result.routes.first.points

      expect(route_pts.first.distance_to_next).to be_nil
      expect(route_pts.first.elevation_change).to be_nil
      expect(route_pts.first.direction).to be_nil
    end
  end

  # -------------------------------------------------------------------
  # max_distance integration
  # -------------------------------------------------------------------
  context 'with max_distance enabled' do
    let(:gpx_far_points) do
      # Two route points ~1113 m apart (0.01 deg lat at ~48°)
      # Two track points ~111 m apart (0.001 deg lat) — below a 200 m limit
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <rte>
            <name>Test Route</name>
            <rtept lat="48.0" lon="16.0"><ele>100.0</ele></rtept>
            <rtept lat="48.01" lon="16.0"><ele>200.0</ele></rtept>
          </rte>
          <trk>
            <name>Test Track</name>
            <trkseg>
              <trkpt lat="48.0" lon="16.0"><ele>100.0</ele></trkpt>
              <trkpt lat="48.001" lon="16.0"><ele>110.0</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
      XML
    end

    it 'inserts intermediate points in segments that exceed max_distance' do
      result = described_class.parse_string(gpx_far_points, params: { max_distance: 200 })
      route_pts = result.routes.first.points

      # ~1113 m / 200 m → ceil = 6 segments → 5 intermediate → total 7 points
      expect(route_pts.length).to eq(7)
      expect(route_pts.first.lat).to be_within(1e-9).of(48.0)
      expect(route_pts.last.lat).to be_within(1e-9).of(48.01)
    end

    it 'does not insert points in segments already within the limit' do
      result = described_class.parse_string(gpx_far_points, params: { max_distance: 200 })
      track_pts = result.tracks.first.segments.first.points

      # ~111 m ≤ 200 m → no split, still 2 points
      expect(track_pts.length).to eq(2)
    end

    it 'interpolates elevation for intermediate points' do
      result = described_class.parse_string(gpx_far_points, params: { max_distance: 200 })
      route_pts = result.routes.first.points

      intermediate = route_pts[1...-1]
      intermediate.each { |pt| expect(pt.ele).to be_a(Float) }
    end

    it 'ensures no sub-segment exceeds max_distance after splitting' do
      result = described_class.parse_string(gpx_far_points, params: { max_distance: 200 })

      result.routes.each do |route|
        route.points.each_cons(2) do |a, b|
          dlat_m = (b.lat - a.lat) * GpxDoctor::SegmentSplitter::METERS_PER_DEGREE_LAT
          avg_lat_rad = (a.lat + b.lat) / 2.0 * Math::PI / 180.0
          dlon_m = (b.lon - a.lon) * GpxDoctor::SegmentSplitter::METERS_PER_DEGREE_LAT * Math.cos(avg_lat_rad)
          dist = Math.sqrt(dlat_m**2 + dlon_m**2)
          expect(dist).to be <= 200
        end
      end
    end

    it 'runs segment splitting before statistics when both params are set' do
      result = described_class.parse_string(
        gpx_far_points,
        params: { max_distance: 200, segment_statistics: true }
      )
      route_pts = result.routes.first.points

      # All but the last should have distance_to_next computed
      expect(route_pts.length).to be > 2
      route_pts[0...-1].each do |pt|
        expect(pt.distance_to_next).to be_a(Float)
        expect(pt.distance_to_next).to be <= 200
      end
      expect(route_pts.last.distance_to_next).to be_nil
    end

    it 'does not split route or track points when max_distance is absent' do
      result = described_class.parse_string(gpx_far_points)
      expect(result.routes.first.points.length).to eq(2)
      expect(result.tracks.first.segments.first.points.length).to eq(2)
    end
  end

  # -------------------------------------------------------------------
  # max_points integration
  # -------------------------------------------------------------------
  context 'with max_points enabled' do
    # Ten route points spaced ~111 m apart (0.001 deg lat each step).
    # Total route distance ≈ 1000 m.  max_points / total ≈ 111 m → no auto max_distance.
    let(:gpx_ten_points) do
      rtepts = (0..9).map do |i|
        lat = (48.0 + i * 0.001).round(4)
        %(<rtept lat="#{lat}" lon="16.0"><ele>#{100 + i * 10}.0</ele></rtept>)
      end.join("\n            ")

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <rte>
            <name>Test Route</name>
            #{rtepts}
          </rte>
        </gpx>
      XML
    end

    it 'reduces route points to max_points' do
      result = described_class.parse_string(gpx_ten_points, params: { max_points: 4 })
      expect(result.routes.first.points.length).to eq(4)
    end

    it 'always keeps first and last point' do
      result = described_class.parse_string(gpx_ten_points, params: { max_points: 4 })
      pts = result.routes.first.points
      expect(pts.first.lat).to be_within(1e-9).of(48.0)
      expect(pts.last.lat).to be_within(1e-9).of(48.009)
    end

    it 'does not reduce points when max_points >= number of points' do
      result = described_class.parse_string(gpx_ten_points, params: { max_points: 20 })
      expect(result.routes.first.points.length).to eq(10)
    end

    it 'follows the sequence: max_distance then max_points then segment_statistics' do
      # Apply max_distance 200 (splits 10-point route) then max_points 5
      result = described_class.parse_string(
        gpx_ten_points,
        params: { max_distance: 200, max_points: 5, segment_statistics: true }
      )
      pts = result.routes.first.points
      expect(pts.length).to eq(5)
      # Statistics must have been run after max_points selection
      pts[0...-1].each { |pt| expect(pt.distance_to_next).to be_a(Float) }
      expect(pts.last.distance_to_next).to be_nil
    end
  end

  # -------------------------------------------------------------------
  # Auto max_distance when max_points ratio > 1000 m
  # -------------------------------------------------------------------
  context 'with max_points and auto max_distance' do
    # Two route points ~11_132 m apart (0.1 deg lat).
    # With max_points = 5: ratio = 11_132 / 5 ≈ 2226 m > 1000 m
    # → auto max_distance = 500 m (splits the pair into ~23 segments)
    # After splitting we get many points; then 5 are selected.
    let(:gpx_far_two_points) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <rte>
            <name>Long Route</name>
            <rtept lat="48.0" lon="16.0"><ele>100.0</ele></rtept>
            <rtept lat="48.1" lon="16.0"><ele>200.0</ele></rtept>
          </rte>
        </gpx>
      XML
    end

    it 'auto-applies max_distance 500 and then selects max_points points' do
      result = described_class.parse_string(gpx_far_two_points, params: { max_points: 5 })
      pts = result.routes.first.points
      # Exactly 5 points selected after auto split
      expect(pts.length).to eq(5)
    end

    it 'keeps first and last point when auto max_distance is triggered' do
      result = described_class.parse_string(gpx_far_two_points, params: { max_points: 5 })
      pts = result.routes.first.points
      expect(pts.first.lat).to be_within(1e-9).of(48.0)
      expect(pts.last.lat).to be_within(1e-9).of(48.1)
    end

    it 'does not auto-apply max_distance when ratio is below 1000 m' do
      # Two points ~111 m apart; max_points 1 → ratio 111 m < 1000 m → no auto split
      gpx = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="test">
          <rte>
            <name>Short Route</name>
            <rtept lat="48.0"   lon="16.0"><ele>100.0</ele></rtept>
            <rtept lat="48.001" lon="16.0"><ele>110.0</ele></rtept>
          </rte>
        </gpx>
      XML
      result = described_class.parse_string(gpx, params: { max_points: 1 })
      # Only 1 point selected, no intermediate points added
      expect(result.routes.first.points.length).to eq(1)
    end
  end
end


