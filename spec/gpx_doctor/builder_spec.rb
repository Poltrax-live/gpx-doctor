# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe GpxDoctor::Builder do
  let(:fixture_path) { File.expand_path('../fixtures/sample.gpx', __dir__) }
  let(:parsed)       { GpxDoctor::Parser.parse(fixture_path) }
  let(:xml_string)   { described_class.build(parsed) }
  let(:doc)          { Nokogiri::XML(xml_string) }
  let(:ns)           { { 'g' => GpxDoctor::Builder::GPX_NS } }

  describe '.build' do
    it 'returns a String' do
      expect(xml_string).to be_a(String)
    end

    it 'produces valid XML' do
      expect(doc.errors).to be_empty
    end

    it 'sets the GPX version attribute' do
      expect(doc.root['version']).to eq('1.1')
    end

    it 'sets the creator attribute' do
      expect(doc.root['creator']).to eq('GPX Doctor')
    end

    it 'accepts a custom creator' do
      output = described_class.build(parsed, creator: 'My App')
      expect(Nokogiri::XML(output).root['creator']).to eq('My App')
    end

    it 'includes the GPX namespace' do
      expect(doc.root.namespace.href).to eq(GpxDoctor::Builder::GPX_NS)
    end

    context 'metadata' do
      it 'serialises the metadata name' do
        expect(doc.at_xpath('//g:metadata/g:name', ns).text).to eq('Sample GPX')
      end

      it 'serialises the metadata description' do
        expect(doc.at_xpath('//g:metadata/g:desc', ns).text).to eq('A sample GPX file for testing')
      end

      it 'serialises the metadata time as ISO 8601' do
        time_text = doc.at_xpath('//g:metadata/g:time', ns).text
        expect { Time.parse(time_text) }.not_to raise_error
      end

      it 'serialises the metadata keywords' do
        expect(doc.at_xpath('//g:metadata/g:keywords', ns).text).to eq('test, sample, gpx')
      end

      it 'serialises the author name' do
        expect(doc.at_xpath('//g:metadata/g:author/g:name', ns).text).to eq('Jane Doe')
      end

      it 'serialises the author email' do
        email_el = doc.at_xpath('//g:metadata/g:author/g:email', ns)
        expect(email_el['id']).to eq('jane')
        expect(email_el['domain']).to eq('example.com')
      end

      it 'serialises the author link' do
        link_el = doc.at_xpath('//g:metadata/g:author/g:link', ns)
        expect(link_el['href']).to eq('https://example.com/jane')
        expect(link_el.at_xpath('g:text', ns).text).to eq("Jane's page")
      end

      it 'serialises copyright' do
        cr = doc.at_xpath('//g:metadata/g:copyright', ns)
        expect(cr['author']).to eq('Jane Doe')
        expect(cr.at_xpath('g:year', ns).text).to eq('2024')
      end

      it 'serialises bounds attributes' do
        bounds = doc.at_xpath('//g:metadata/g:bounds', ns)
        expect(bounds['minlat'].to_f).to eq(48.0)
        expect(bounds['maxlon'].to_f).to eq(17.0)
      end
    end

    context 'waypoints' do
      it 'serialises one top-level waypoint' do
        expect(doc.xpath('//g:gpx/g:wpt', ns).length).to eq(1)
      end

      it 'preserves lat/lon on the waypoint' do
        wpt = doc.at_xpath('//g:gpx/g:wpt', ns)
        expect(wpt['lat'].to_f).to be_within(0.0001).of(48.2093723)
        expect(wpt['lon'].to_f).to be_within(0.0001).of(16.356099)
      end

      it 'preserves elevation' do
        expect(doc.at_xpath('//g:gpx/g:wpt/g:ele', ns).text.to_f).to eq(160.0)
      end

      it 'preserves name and desc' do
        wpt = doc.at_xpath('//g:gpx/g:wpt', ns)
        expect(wpt.at_xpath('g:name', ns).text).to eq('Waypoint 1')
        expect(wpt.at_xpath('g:desc', ns).text).to eq('A standalone waypoint')
      end

      it 'preserves time as ISO 8601' do
        time_text = doc.at_xpath('//g:gpx/g:wpt/g:time', ns).text
        expect { Time.parse(time_text) }.not_to raise_error
      end
    end

    context 'routes' do
      it 'serialises one route' do
        expect(doc.xpath('//g:gpx/g:rte', ns).length).to eq(1)
      end

      it 'preserves the route name' do
        expect(doc.at_xpath('//g:gpx/g:rte/g:name', ns).text).to eq('Route 1')
      end

      it 'serialises route points as rtept' do
        expect(doc.xpath('//g:gpx/g:rte/g:rtept', ns).length).to eq(2)
      end

      it 'preserves route point coordinates' do
        rtept = doc.xpath('//g:gpx/g:rte/g:rtept', ns).first
        expect(rtept['lat'].to_f).to be_within(0.0001).of(48.21)
        expect(rtept['lon'].to_f).to be_within(0.0001).of(16.36)
      end
    end

    context 'tracks' do
      it 'serialises one track' do
        expect(doc.xpath('//g:gpx/g:trk', ns).length).to eq(1)
      end

      it 'preserves the track name' do
        expect(doc.at_xpath('//g:gpx/g:trk/g:name', ns).text).to eq('Track 1')
      end

      it 'serialises track segments as trkseg' do
        expect(doc.xpath('//g:gpx/g:trk/g:trkseg', ns).length).to eq(1)
      end

      it 'serialises track points as trkpt' do
        expect(doc.xpath('//g:gpx/g:trk/g:trkseg/g:trkpt', ns).length).to eq(2)
      end

      it 'preserves track point coordinates' do
        trkpt = doc.xpath('//g:gpx/g:trk/g:trkseg/g:trkpt', ns).first
        expect(trkpt['lat'].to_f).to be_within(0.0001).of(48.23)
        expect(trkpt['lon'].to_f).to be_within(0.0001).of(16.38)
      end
    end

    context 'round-trip point count' do
      it 'preserves the total number of points' do
        re_parsed = GpxDoctor::Parser.parse_string(xml_string)
        expect(re_parsed.points.length).to eq(parsed.points.length)
      end
    end
  end

  describe '.build_file' do
    it 'writes the XML to disk and returns the XML string' do
      Dir.mktmpdir do |dir|
        path   = File.join(dir, 'output.gpx')
        result = described_class.build_file(parsed, path)

        expect(File.exist?(path)).to be true
        expect(File.read(path)).to eq(result)
        expect(result).to be_a(String)
      end
    end

    it 'produces a file that can be re-parsed' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'output.gpx')
        described_class.build_file(parsed, path)
        re_parsed = GpxDoctor::Parser.parse(path)
        expect(re_parsed.points.length).to eq(parsed.points.length)
      end
    end
  end
end
