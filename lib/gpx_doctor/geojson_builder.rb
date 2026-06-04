# frozen_string_literal: true

require 'json'

module GpxDoctor
  # Builds GeoJSON output from parsed GPX data according to RFC 7946.
  #
  # RFC 7946 compliance:
  # - Coordinate order: [longitude, latitude, elevation]
  # - LineString geometries require minimum 2 positions
  # - MultiLineString segments require minimum 2 positions each
  # - Empty or invalid geometries are filtered out
  # - Properties member is null when no properties exist
  class GeoJsonBuilder
    class << self
      def build(result)
        new(result).build
      end

      def build_file(result, file_path)
        json = build(result)
        File.write(file_path, json)
        json
      end
    end

    def initialize(result)
      @result = result
    end

    def build
      features = []
      features.concat(waypoint_features)
      features.concat(route_features)
      features.concat(track_features)

      JSON.generate(
        type: 'FeatureCollection',
        features: features
      )
    end

    private

    def waypoint_features
      @result.waypoints.map { |wpt| point_feature(wpt) }
    end

    def route_features
      @result.routes.map do |route|
        coords = route.points.map { |pt| coordinate(pt) }
        # RFC 7946: LineString must have 2 or more positions
        next if coords.length < 2

        props = route_properties(route)
        {
          type: 'Feature',
          properties: props.empty? ? nil : props,
          geometry: {
            type: 'LineString',
            coordinates: coords
          }
        }
      end.compact
    end

    def track_features
      @result.tracks.map do |track|
        # RFC 7946: Each LineString in MultiLineString must have 2+ positions
        coords = track.segments.map do |seg|
          seg_coords = seg.points.map { |pt| coordinate(pt) }
          seg_coords if seg_coords.length >= 2
        end.compact

        # Skip tracks with no valid segments
        next if coords.empty?

        props = track_properties(track)
        {
          type: 'Feature',
          properties: props.empty? ? nil : props,
          geometry: {
            type: 'MultiLineString',
            coordinates: coords
          }
        }
      end.compact
    end

    def point_feature(wpt)
      props = waypoint_properties(wpt)
      {
        type: 'Feature',
        properties: props.empty? ? nil : props,
        geometry: {
          type: 'Point',
          coordinates: coordinate(wpt)
        }
      }
    end

    def coordinate(point)
      coord = [point.lon, point.lat]
      coord << point.ele if point.ele
      coord
    end

    def waypoint_properties(wpt)
      props = {}
      props[:name]  = wpt.name  if wpt.name
      props[:desc]  = wpt.desc  if wpt.desc
      props[:sym]   = wpt.sym   if wpt.sym
      props[:type]  = wpt.type  if wpt.type
      props[:time]  = wpt.time.iso8601 if wpt.time
      props
    end

    def route_properties(route)
      props = {}
      props[:name]   = route.name   if route.name
      props[:desc]   = route.desc   if route.desc
      props[:type]   = route.type   if route.type
      props[:number] = route.number if route.number
      props
    end

    def track_properties(track)
      props = {}
      props[:name]   = track.name   if track.name
      props[:desc]   = track.desc   if track.desc
      props[:type]   = track.type   if track.type
      props[:number] = track.number if track.number
      props
    end
  end
end
