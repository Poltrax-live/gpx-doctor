# frozen_string_literal: true

require "spec_helper"

RSpec.describe GpxDoctor::Parser do
  let(:fixture_path) { File.expand_path("../fixtures/sample.gpx", __dir__) }
  let(:fixture_xml)  { File.read(fixture_path) }
  let(:result)       { described_class.parse(fixture_path) }
  let(:result_from_string) { described_class.parse_string(fixture_xml) }

  describe ".parse" do
    it "returns a Result object" do
      expect(result).to be_a(GpxDoctor::Parser::Result)
    end

    it "produces the same output as parse_string" do
      expect(result.points.length).to eq(result_from_string.points.length)
    end
  end

  describe "#waypoints" do
    it "returns the top-level wpt elements" do
      expect(result.waypoints.length).to eq(1)
    end

    it "has correct lat/lon" do
      wpt = result.waypoints.first
      expect(wpt.lat).to be_within(0.0001).of(48.2093723)
      expect(wpt.lon).to be_within(0.0001).of(16.356099)
    end

    it "has elevation" do
      expect(result.waypoints.first.ele).to eq(160.0)
    end

    it "has name and desc" do
      wpt = result.waypoints.first
      expect(wpt.name).to eq("Waypoint 1")
      expect(wpt.desc).to eq("A standalone waypoint")
    end

    it "has time as a Time object" do
      expect(result.waypoints.first.time).to be_a(Time)
    end
  end

  describe "#routes" do
    it "returns route objects" do
      expect(result.routes.length).to eq(1)
    end

    it "has route name" do
      expect(result.routes.first.name).to eq("Route 1")
    end

    it "has route points" do
      expect(result.routes.first.points.length).to eq(2)
    end

    it "has correct route point coordinates" do
      pt = result.routes.first.points.first
      expect(pt.lat).to be_within(0.0001).of(48.21)
      expect(pt.lon).to be_within(0.0001).of(16.36)
      expect(pt.ele).to eq(155.0)
    end
  end

  describe "#tracks" do
    it "returns track objects" do
      expect(result.tracks.length).to eq(1)
    end

    it "has track name" do
      expect(result.tracks.first.name).to eq("Track 1")
    end

    it "has segments" do
      expect(result.tracks.first.segments.length).to eq(1)
    end

    it "has track points in segment" do
      expect(result.tracks.first.segments.first.points.length).to eq(2)
    end

    it "exposes all track points via #points" do
      expect(result.tracks.first.points.length).to eq(2)
    end

    it "has correct track point coordinates" do
      pt = result.tracks.first.points.first
      expect(pt.lat).to be_within(0.0001).of(48.23)
      expect(pt.lon).to be_within(0.0001).of(16.38)
      expect(pt.ele).to eq(170.0)
    end
  end

  describe "#points" do
    it "contains all geographic points (wpt + rtept + trkpt)" do
      # 1 wpt + 2 rtept + 2 trkpt = 5
      expect(result.points.length).to eq(5)
    end

    it "contains Waypoint objects" do
      expect(result.points).to all(be_a(GpxDoctor::Models::Waypoint))
    end
  end

  describe "#metadata" do
    subject(:meta) { result.metadata }

    it "is a Metadata object" do
      expect(meta).to be_a(GpxDoctor::Models::Metadata)
    end

    it "has name" do
      expect(meta.name).to eq("Sample GPX")
    end

    it "has desc" do
      expect(meta.desc).to eq("A sample GPX file for testing")
    end

    it "has keywords" do
      expect(meta.keywords).to eq("test, sample, gpx")
    end

    it "has time as a Time object" do
      expect(meta.time).to be_a(Time)
    end

    it "has links" do
      expect(meta.links.length).to eq(1)
      expect(meta.links.first.href).to eq("https://example.com/gpx")
      expect(meta.links.first.text).to eq("Source")
    end

    describe "author" do
      subject(:author) { meta.author }

      it "is a Person" do
        expect(author).to be_a(GpxDoctor::Models::Person)
      end

      it "has name" do
        expect(author.name).to eq("Jane Doe")
      end

      it "has email" do
        expect(author.email).to be_a(GpxDoctor::Models::Email)
        expect(author.email.to_s).to eq("jane@example.com")
      end

      it "has link" do
        expect(author.link).to be_a(GpxDoctor::Models::Link)
        expect(author.link.href).to eq("https://example.com/jane")
      end
    end

    describe "copyright" do
      subject(:copyright) { meta.copyright }

      it "is a Copyright" do
        expect(copyright).to be_a(GpxDoctor::Models::Copyright)
      end

      it "has author" do
        expect(copyright.author).to eq("Jane Doe")
      end

      it "has year" do
        expect(copyright.year).to eq("2024")
      end

      it "has license" do
        expect(copyright.license).to eq("https://creativecommons.org/licenses/by/4.0/")
      end
    end

    describe "bounds" do
      subject(:bounds) { meta.bounds }

      it "is a Bounds" do
        expect(bounds).to be_a(GpxDoctor::Models::Bounds)
      end

      it "has correct values" do
        expect(bounds.minlat).to eq(48.0)
        expect(bounds.minlon).to eq(16.0)
        expect(bounds.maxlat).to eq(49.0)
        expect(bounds.maxlon).to eq(17.0)
      end
    end
  end

  describe "Waypoint#to_h" do
    subject(:wpt) { result.waypoints.first }

    it "includes lat, lon, ele" do
      h = wpt.to_h
      expect(h[:lat]).to be_a(Float)
      expect(h[:lon]).to be_a(Float)
      expect(h[:ele]).to eq(160.0)
    end

    it "excludes nil fields" do
      h = wpt.to_h
      expect(h.keys).not_to include(:magvar)
    end

    it "includes name" do
      expect(wpt.to_h[:name]).to eq("Waypoint 1")
    end
  end
end
