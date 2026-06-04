# frozen_string_literal: true

require 'json'

module GpxDoctor
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
        {
          type: 'Feature',
          properties: route_properties(route),
          geometry: {
            type: 'LineString',
            coordinates: route.points.map { |pt| coordinate(pt) }
          }
        }
      end
    end

    def track_features
      @result.tracks.map do |track|
        {
          type: 'Feature',
          properties: track_properties(track),
          geometry: {
            type: 'MultiLineString',
            coordinates: track.segments.map do |seg|
              seg.points.map { |pt| coordinate(pt) }
            end
          }
        }
      end
    end

    def point_feature(wpt)
      {
        type: 'Feature',
        properties: waypoint_properties(wpt),
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
