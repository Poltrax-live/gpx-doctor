# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'nokogiri'

# End-to-end scenario tests: parse a GPX file (optionally with processing params),
# then generate a new GPX from the result via Builder, and verify the output is a
# valid, well-formed GPX whose contents match the expected transformations.
RSpec.describe 'GPX parse → transform → build scenarios' do
  GPX_NS = GpxDoctor::Builder::GPX_NS

  # Helper: parse the produced XML string with Nokogiri and return the doc + ns map.
  def parse_output(xml)
    doc = Nokogiri::XML(xml)
    expect(doc.errors).to be_empty
    [doc, { 'g' => GPX_NS }]
  end

  # Helper: re-parse the produced XML through GpxDoctor::Parser.
  def reparse(xml)
    GpxDoctor::Parser.parse_string(xml)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 1 – plain round-trip (no transformation params)
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 1: plain round-trip on sample.gpx' do
    let(:fixture) { File.expand_path('../fixtures/sample.gpx', __dir__) }
    let(:parsed)  { GpxDoctor::Parser.parse(fixture) }
    let(:output)  { GpxDoctor::Builder.build(parsed) }

    it 'produces valid XML with the correct GPX namespace' do
      doc, ns = parse_output(output)
      expect(doc.root.namespace.href).to eq(GPX_NS)
    end

    it 'preserves all waypoints' do
      expect(reparse(output).waypoints.length).to eq(parsed.waypoints.length)
    end

    it 'preserves all route points' do
      original_rte_pts = parsed.routes.sum { |r| r.points.length }
      output_rte_pts   = reparse(output).routes.sum { |r| r.points.length }
      expect(output_rte_pts).to eq(original_rte_pts)
    end

    it 'preserves all track points' do
      original_trk_pts = parsed.tracks.flat_map { |t| t.segments }.sum { |s| s.points.length }
      output_trk_pts   = reparse(output).tracks.flat_map { |t| t.segments }.sum { |s| s.points.length }
      expect(output_trk_pts).to eq(original_trk_pts)
    end

    it 'preserves total point count' do
      expect(reparse(output).points.length).to eq(parsed.points.length)
    end

    it 'preserves metadata name' do
      expect(reparse(output).metadata.name).to eq(parsed.metadata.name)
    end

    it 'preserves metadata author' do
      expect(reparse(output).metadata.author.name).to eq(parsed.metadata.author.name)
    end

    it 'preserves waypoint coordinates' do
      orig = parsed.waypoints.first
      out  = reparse(output).waypoints.first
      expect(out.lat).to be_within(0.000001).of(orig.lat)
      expect(out.lon).to be_within(0.000001).of(orig.lon)
    end

    it 'preserves waypoint elevation' do
      expect(reparse(output).waypoints.first.ele).to eq(parsed.waypoints.first.ele)
    end

    it 'preserves waypoint time' do
      orig_time = parsed.waypoints.first.time
      out_time  = reparse(output).waypoints.first.time
      expect(out_time.to_i).to eq(orig_time.to_i)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 2 – max_points reduction
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 2: max_points on aus.gpx' do
    let(:fixture)    { File.expand_path('../fixtures/aus.gpx', __dir__) }
    let(:max_points) { 200 }
    let(:parsed)     { GpxDoctor::Parser.parse(fixture, params: { max_points: max_points }) }
    let(:output)     { GpxDoctor::Builder.build(parsed) }

    it 'produces valid XML' do
      parse_output(output)
    end

    it 'limits total points to the requested maximum' do
      expect(parsed.points.length).to eq(max_points)
    end

    it 're-parsed output has the same number of points as the reduced result' do
      expect(reparse(output).points.length).to eq(max_points)
    end

    it 'preserves first and last coordinates after reduction' do
      orig_first = parsed.points.first
      orig_last  = parsed.points.last
      out_first  = reparse(output).points.first
      out_last   = reparse(output).points.last

      expect(out_first.lat).to be_within(0.000001).of(orig_first.lat)
      expect(out_first.lon).to be_within(0.000001).of(orig_first.lon)
      expect(out_last.lat).to be_within(0.000001).of(orig_last.lat)
      expect(out_last.lon).to be_within(0.000001).of(orig_last.lon)
    end

    it 'produces fewer points than the original (unreduced) file' do
      original_count = GpxDoctor::Parser.parse(fixture).points.length
      expect(parsed.points.length).to be < original_count
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 3 – max_distance segment splitting
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 3: max_distance splitting on gory.gpx' do
    let(:fixture)      { File.expand_path('../fixtures/gory.gpx', __dir__) }
    let(:max_distance) { 50 }
    let(:parsed)       { GpxDoctor::Parser.parse(fixture, params: { max_distance: max_distance }) }
    let(:output)       { GpxDoctor::Builder.build(parsed) }

    it 'produces valid XML' do
      parse_output(output)
    end

    it 'adds interpolated points so total is greater than without splitting' do
      original_count = GpxDoctor::Parser.parse(fixture).points.length
      expect(parsed.points.length).to be > original_count
    end

    it 're-parsed output preserves the expanded point count' do
      expect(reparse(output).points.length).to eq(parsed.points.length)
    end

    it 'ensures no consecutive track points exceed max_distance' do
      reparsed = reparse(output)
      reparsed.tracks.each do |trk|
        trk.segments.each do |seg|
          seg.points.each_cons(2) do |a, b|
            dist = GpxDoctor::DistanceCalculator.distance(a, b)
            expect(dist).to be <= max_distance + 0.001
          end
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 4 – max_distance + max_points combined
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 4: max_distance + max_points on gory.gpx' do
    let(:fixture)      { File.expand_path('../fixtures/gory.gpx', __dir__) }
    let(:max_distance) { 200 }
    let(:max_points)   { 500 }
    let(:parsed) do
      GpxDoctor::Parser.parse(fixture, params: { max_distance: max_distance, max_points: max_points })
    end
    let(:output) { GpxDoctor::Builder.build(parsed) }

    it 'produces valid XML' do
      parse_output(output)
    end

    it 'limits total points to max_points' do
      expect(parsed.points.length).to eq(max_points)
    end

    it 're-parsed output has the same point count' do
      expect(reparse(output).points.length).to eq(max_points)
    end

    it 'preserves track structure (one track, one segment)' do
      reparsed = reparse(output)
      expect(reparsed.tracks.length).to eq(parsed.tracks.length)
      expect(reparsed.tracks.first.segments.length).to eq(parsed.tracks.first.segments.length)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 5 – segment_statistics enrichment
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 5: segment_statistics on aus.gpx' do
    let(:fixture) { File.expand_path('../fixtures/aus.gpx', __dir__) }
    let(:parsed)  { GpxDoctor::Parser.parse(fixture, params: { segment_statistics: true }) }
    let(:output)  { GpxDoctor::Builder.build(parsed) }

    it 'populates distance_to_next on parsed points' do
      pts = parsed.points
      # All but the last point should have a distance_to_next value
      expect(pts.first.distance_to_next).not_to be_nil
      expect(pts.last.distance_to_next).to be_nil
    end

    it 'populates direction (bearing) on parsed points' do
      expect(parsed.points.first.direction).not_to be_nil
    end

    it 'produces valid XML from a statistics-enriched result' do
      parse_output(output)
    end

    it 'statistics fields are not serialised as GPX elements (GPX has no such fields)' do
      doc, ns = parse_output(output)
      # distance_to_next, elevation_change, direction are not GPX elements
      expect(doc.xpath('//g:distance_to_next', ns)).to be_empty
      expect(doc.xpath('//g:elevation_change', ns)).to be_empty
      expect(doc.xpath('//g:direction', ns)).to be_empty
    end

    it 're-parsed output preserves all points' do
      expect(reparse(output).points.length).to eq(parsed.points.length)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Scenario 6 – build_file: write to disk, then parse the written file
  # ─────────────────────────────────────────────────────────────────────────────
  describe 'Scenario 6: build_file round-trip on aus.gpx' do
    let(:fixture)    { File.expand_path('../fixtures/aus.gpx', __dir__) }
    let(:max_points) { 150 }
    let(:parsed)     { GpxDoctor::Parser.parse(fixture, params: { max_points: max_points }) }

    it 'writes a file that GpxDoctor::Parser can read back' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'output.gpx')
        GpxDoctor::Builder.build_file(parsed, path)

        expect(File.exist?(path)).to be true
        reparsed = GpxDoctor::Parser.parse(path)
        expect(reparsed.points.length).to eq(max_points)
      end
    end

    it 'written file is valid XML' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'output.gpx')
        GpxDoctor::Builder.build_file(parsed, path)
        doc = Nokogiri::XML(File.read(path))
        expect(doc.errors).to be_empty
      end
    end

    it 'written file preserves coordinates of the first point' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'output.gpx')
        GpxDoctor::Builder.build_file(parsed, path)

        orig_first = parsed.points.first
        out_first  = GpxDoctor::Parser.parse(path).points.first
        expect(out_first.lat).to be_within(0.000001).of(orig_first.lat)
        expect(out_first.lon).to be_within(0.000001).of(orig_first.lon)
      end
    end
  end
end
