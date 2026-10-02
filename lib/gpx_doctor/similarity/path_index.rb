# frozen_string_literal: true

module GpxDoctor
  class Similarity
    # Spatial index over a reference path answering "is this coordinate within
    # +tolerance+ metres of the path?" in roughly constant time.
    #
    # The path is stored as line segments rather than as bare vertices, so a
    # coordinate sitting *between* two consecutive reference points counts as
    # being on the path. Segments are bucketed into a uniform latitude/longitude
    # grid whose cells are at least +tolerance+ metres wide, which means a query
    # only has to measure the segments registered in the 3x3 block of cells
    # around it: anything closer than +tolerance+ is at most one cell away, and
    # a segment is registered in every cell its bounding box touches.
    #
    # Reference segments longer than one cell are subdivided before indexing so
    # that a single segment never spans more than a handful of cells.
    class PathIndex
      METERS_PER_DEGREE = Geo::METERS_PER_DEGREE
      # Keeps the longitude cell size finite when cos(latitude) collapses to
      # zero next to the poles.
      MIN_COS_LAT = 0.01
      # Cells are sized for the latitude band of the reference path; widening
      # that band keeps them wide enough for queries sitting beyond it too.
      LAT_MARGIN_DEG = 1.0
      # Upper bound on the segments produced by subdividing the reference path.
      # It is only reached by extreme tolerance/length combinations, where it
      # trades bigger grid cells (more candidates per query) for bounded memory.
      MAX_SEGMENTS = 250_000

      # +collections+ is an array of point sequences ([lat, lon] pairs), one per
      # route or track segment, so that no segment is implied between the end of
      # one sequence and the start of the next.
      def initialize(collections, tolerance)
        @tolerance_squared = tolerance.to_f**2
        @cells = {}
        build(collections, tolerance.to_f)
      end

      # True when [lat, lon] lies within tolerance metres of the reference path.
      def close?(lat, lon)
        cos_lat = Math.cos(lat * Geo::DEG_TO_RAD)
        lat_cell = cell_index(lat, @cell_lat_deg)
        lon_cell = cell_index(lon, @cell_lon_deg)

        (-1..1).each do |lat_offset|
          (-1..1).each do |lon_offset|
            segments = @cells[[lat_cell + lat_offset, lon_cell + lon_offset]]
            next unless segments

            segments.each do |segment|
              return true if squared_distance_to_segment(lat, lon, cos_lat, segment) <= @tolerance_squared
            end
          end
        end

        false
      end

      private

      def build(collections, tolerance)
        total_length, max_abs_lat = path_metrics(collections)
        cell_meters = [tolerance, total_length / MAX_SEGMENTS].max

        @cell_lat_deg = cell_meters / METERS_PER_DEGREE
        @cell_lon_deg = cell_meters / (METERS_PER_DEGREE * narrowest_cos_lat(max_abs_lat))

        collections.each { |points| index_collection(points, cell_meters) }
      end

      # Cells must stay at least +tolerance+ metres wide for the 3x3 block
      # around a query to cover everything within the tolerance, so the
      # longitude size is computed for the narrowest degree of the band.
      def narrowest_cos_lat(max_abs_lat)
        [Math.cos([max_abs_lat + LAT_MARGIN_DEG, 90.0].min * Geo::DEG_TO_RAD), MIN_COS_LAT].max
      end

      # [total path length in metres, greatest absolute latitude] — the first
      # bounds the number of indexed segments, the second the cell width.
      def path_metrics(collections)
        total_length = 0.0
        max_abs_lat = 0.0

        collections.each do |points|
          points.each do |(lat, _lon)|
            max_abs_lat = lat.abs if lat.abs > max_abs_lat
          end
          points.each_cons(2) { |a, b| total_length += Geo.distance(a, b) }
        end

        [total_length, max_abs_lat]
      end

      def index_collection(points, cell_meters)
        if points.size == 1
          lat, lon = points.first
          index_segment([lat, lon, lat, lon])
          return
        end

        points.each_cons(2) { |a, b| index_pair(a, b, cell_meters) }
      end

      def index_pair(a, b, cell_meters)
        distance = Geo.distance(a, b)
        steps = distance > cell_meters ? (distance / cell_meters).ceil : 1

        previous = a
        (1..steps).each do |step|
          current = step == steps ? b : Geo.interpolate(a, b, step.to_f / steps)
          index_segment([previous[0], previous[1], current[0], current[1]])
          previous = current
        end
      end

      def index_segment(segment)
        lat_cells = cell_range(segment[0], segment[2], @cell_lat_deg)
        lon_cells = cell_range(segment[1], segment[3], @cell_lon_deg)

        lat_cells.each do |lat_cell|
          lon_cells.each do |lon_cell|
            (@cells[[lat_cell, lon_cell]] ||= []) << segment
          end
        end
      end

      def cell_range(from, to, cell_size)
        low, high = from <= to ? [from, to] : [to, from]
        cell_index(low, cell_size)..cell_index(high, cell_size)
      end

      def cell_index(degrees, cell_size)
        (degrees / cell_size).floor
      end

      # Squared distance in metres² from [lat, lon] to the closest position on
      # +segment+, measured on a local plane centred on the queried coordinate.
      def squared_distance_to_segment(lat, lon, cos_lat, segment)
        ax = (segment[1] - lon) * METERS_PER_DEGREE * cos_lat
        ay = (segment[0] - lat) * METERS_PER_DEGREE
        bx = (segment[3] - lon) * METERS_PER_DEGREE * cos_lat
        by = (segment[2] - lat) * METERS_PER_DEGREE

        dx = bx - ax
        dy = by - ay
        length_squared = dx * dx + dy * dy

        if length_squared.zero?
          nearest_x = ax
          nearest_y = ay
        else
          # Projection of the queried coordinate (the origin) onto the segment.
          fraction = -(ax * dx + ay * dy) / length_squared
          fraction = 0.0 if fraction < 0.0
          fraction = 1.0 if fraction > 1.0
          nearest_x = ax + fraction * dx
          nearest_y = ay + fraction * dy
        end

        nearest_x * nearest_x + nearest_y * nearest_y
      end
    end
  end
end
