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
  context 'with elevation server configured' do
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
      result = described_class.parse_string(gpx_without_ele)

      wpt_enhanced = result.waypoints.find { |w| w.name == 'No Elevation' }
      expect(wpt_enhanced.ele).to eq(171.0)
    end

    it 'does not overwrite existing elevation values' do
      result = described_class.parse_string(gpx_without_ele)

      wpt_existing = result.waypoints.find { |w| w.name == 'Has Elevation' }
      expect(wpt_existing.ele).to eq(500.0)
    end

    it 'enhances track points without elevation' do
      result = described_class.parse_string(gpx_without_ele)

      trkpt = result.tracks.first.points.first
      expect(trkpt.ele).to eq(320.5)
    end
  end

  context 'with elevation server disabled (default)' do
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

    it 'does not fetch elevation data' do
      expect_any_instance_of(GpxDoctor::ElevationClient).not_to receive(:enhance)

      result = described_class.parse_string(gpx_without_ele)
      expect(result.waypoints.first.ele).to be_nil
    end
  end
end
