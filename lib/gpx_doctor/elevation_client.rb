# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module GpxDoctor
  class ElevationClient
    MAX_REQUEST_LINE_BYTES = 1024
    LOOKUP_PATH = '/api/v1/lookup'

    def initialize(config = GpxDoctor.configuration)
      @base_url = config.elevation_server_url
      @user     = config.elevation_server_user
      @password = config.elevation_server_password
    end

    # Enhances waypoints that have nil ele with elevation from the server.
    # Mutates the waypoints in place.
    def enhance(waypoints)
      missing = waypoints.select { |wp| wp.ele.nil? }
      return if missing.empty?

      batches(missing).each do |batch|
        elevations = fetch_elevations(batch)
        batch.zip(elevations).each do |wp, elev|
          wp.ele = elev if elev
        end
      end
    end

    private

    # Splits points into batches that fit within the GET URL byte limit.
    def batches(points)
      base_uri_length = "#{@base_url}#{LOOKUP_PATH}?locations=".bytesize
      available = MAX_REQUEST_LINE_BYTES - base_uri_length

      result = []
      current_batch = []
      current_length = 0

      points.each do |wp|
        location = "#{wp.lat},#{wp.lon}"
        # Account for the '|' separator between locations
        entry_length = current_batch.empty? ? location.bytesize : (location.bytesize + 1)

        if current_length + entry_length > available && !current_batch.empty?
          result << current_batch
          current_batch = [wp]
          current_length = location.bytesize
        else
          current_batch << wp
          current_length += entry_length
        end
      end

      result << current_batch unless current_batch.empty?
      result
    end

    def fetch_elevations(batch)
      locations = batch.map { |wp| "#{wp.lat},#{wp.lon}" }.join('|')
      uri = URI("#{@base_url}#{LOOKUP_PATH}?locations=#{locations}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request.basic_auth(@user, @password) if @user && @password

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        warn "GpxDoctor: Elevation lookup failed (HTTP #{response.code})"
        return Array.new(batch.size)
      end

      parse_response(response.body, batch.size)
    rescue StandardError => e
      warn "GpxDoctor: Elevation lookup error: #{e.message}"
      Array.new(batch.size)
    end

    def parse_response(body, expected_count)
      data = JSON.parse(body)
      results = data['results'] || []

      elevations = results.map { |r| r['elevation']&.to_f }

      # Pad with nils if the response has fewer results than expected
      elevations.fill(nil, elevations.size...expected_count) if elevations.size < expected_count
      elevations
    end
  end
end
