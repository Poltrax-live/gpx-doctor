# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::ElevationClient do
  let(:base_url) { 'http://localhost:19292' }
  let(:client) do
    config = GpxDoctor::Configuration.new
    config.elevation_server     = true
    config.elevation_server_url = base_url
    described_class.new(config)
  end

  def make_waypoint(lat:, lon:, ele: nil)
    GpxDoctor::Models::Waypoint.new(lat: lat, lon: lon, ele: ele)
  end

  describe '#enhance' do
    it 'does nothing when all waypoints already have elevation' do
      wps = [make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0)]
      # Should not make any HTTP call
      client.enhance(wps)
      expect(wps.first.ele).to eq(100.0)
    end

    it 'does nothing when waypoints list is empty' do
      expect { client.enhance([]) }.not_to raise_error
    end

    it 'fetches elevation for waypoints without ele' do
      response_body = {
        'results' => [
          { 'latitude' => 48.0, 'longitude' => 16.0, 'elevation' => 250.5 }
        ]
      }.to_json

      stub_request = nil
      wps = [make_waypoint(lat: 48.0, lon: 16.0)]

      # Stub Net::HTTP to return our response
      fake_response = instance_double(Net::HTTPOK, body: response_body, code: '200')
      allow(fake_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      client.enhance(wps)
      expect(wps.first.ele).to eq(250.5)
    end

    it 'only fetches elevation for waypoints missing ele' do
      response_body = {
        'results' => [
          { 'latitude' => 49.0, 'longitude' => 17.0, 'elevation' => 300.0 }
        ]
      }.to_json

      wp_with_ele    = make_waypoint(lat: 48.0, lon: 16.0, ele: 100.0)
      wp_without_ele = make_waypoint(lat: 49.0, lon: 17.0)

      fake_response = instance_double(Net::HTTPOK, body: response_body, code: '200')
      allow(fake_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      expect_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
        # Verify that only the point without elevation is queried
        expect(req.path).to include('49.0,17.0')
        expect(req.path).not_to include('48.0,16.0')
        fake_response
      end

      client.enhance([wp_with_ele, wp_without_ele])
      expect(wp_with_ele.ele).to eq(100.0)
      expect(wp_without_ele.ele).to eq(300.0)
    end

    it 'handles HTTP errors gracefully' do
      wps = [make_waypoint(lat: 48.0, lon: 16.0)]

      fake_response = instance_double(Net::HTTPInternalServerError, code: '500')
      allow(fake_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      expect { client.enhance(wps) }.not_to raise_error
      expect(wps.first.ele).to be_nil
    end

    it 'handles network errors gracefully' do
      wps = [make_waypoint(lat: 48.0, lon: 16.0)]

      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNREFUSED)

      expect { client.enhance(wps) }.not_to raise_error
      expect(wps.first.ele).to be_nil
    end

    it 'uses basic auth when credentials are configured' do
      config = GpxDoctor::Configuration.new
      config.elevation_server     = true
      config.elevation_server_url = base_url
      config.elevation_server_user     = 'testuser'
      config.elevation_server_password = 'testpass'
      auth_client = described_class.new(config)

      response_body = {
        'results' => [
          { 'latitude' => 48.0, 'longitude' => 16.0, 'elevation' => 200.0 }
        ]
      }.to_json

      fake_response = instance_double(Net::HTTPOK, body: response_body, code: '200')
      allow(fake_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      expect_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
        # Verify basic auth header is present
        expect(req['Authorization']).not_to be_nil
        expect(req['Authorization']).to start_with('Basic ')
        fake_response
      end

      wps = [make_waypoint(lat: 48.0, lon: 16.0)]
      auth_client.enhance(wps)
      expect(wps.first.ele).to eq(200.0)
    end

    it 'batches requests to fit within URL byte limit' do
      # Create enough points that they must be split into multiple batches
      # Each location is roughly 20+ chars: "48.XXXXXX,16.XXXXXX"
      # With a base URL, we should need multiple batches for many points
      waypoints = 80.times.map { |i| make_waypoint(lat: 48.0 + i * 0.001, lon: 16.0 + i * 0.001) }

      call_count = 0
      fake_response_for = lambda do |batch_size|
        body = {
          'results' => batch_size.times.map { |i| { 'latitude' => 0, 'longitude' => 0, 'elevation' => 100.0 + i } }
        }.to_json
        resp = instance_double(Net::HTTPOK, body: body, code: '200')
        allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        resp
      end

      allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
        call_count += 1
        # Count how many locations are in this request
        locations_param = URI(req.path.start_with?('/') ? "http://x#{req.path}" : req.path).query
        location_count = locations_param.split('locations=').last.split('|').size
        fake_response_for.call(location_count)
      end

      client.enhance(waypoints)

      # Should have made multiple HTTP calls
      expect(call_count).to be > 1
      # All waypoints should have elevation
      expect(waypoints.all? { |wp| wp.ele }).to be true
    end
  end
end
