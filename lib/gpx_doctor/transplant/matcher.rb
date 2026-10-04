# frozen_string_literal: true

module GpxDoctor
  class Transplant
    # Core splicing algorithm shared by {Transplant}, {Transplant::Coordinates}
    # and {Transplant::GeoJson}. Each of those only has to turn its own format
    # into (item, [latitude, longitude]) pairs and hand them here.
    #
    # Given a reference sequence of points (the "route") and a shorter
    # sequence to graft onto it (the "transplant"), it finds the route point
    # closest to the transplant's first point and the route point closest to
    # its last point, then returns the route with everything between those two
    # points (inclusive) replaced by the transplant.
    module Matcher
      module_function

      # +route+ and +transplant+ are arrays of +[item, [lat, lon]]+ pairs, in
      # order. Returns the array of +item+s describing the spliced route.
      #
      # +tolerance+, in metres, is the furthest the transplant's start and end
      # may sit from the route; pass +nil+ to skip that check and always graft
      # onto the nearest points regardless of distance.
      def splice(route, transplant, tolerance:)
        raise ArgumentError, 'the route holds no points' if route.empty?
        raise ArgumentError, 'the transplant holds no points' if transplant.empty?

        start_index, start_distance = nearest(route, transplant.first[1])
        end_index, end_distance = nearest(route, transplant.last[1])

        check_tolerance!(start_distance, tolerance, 'start')
        check_tolerance!(end_distance, tolerance, 'end')

        if end_index < start_index
          raise ArgumentError, 'the transplant end lies before its start on the route; cannot determine a section to replace'
        end

        before = route[0...start_index].map(&:first)
        after = route[(end_index + 1)..-1].map(&:first)

        before + transplant.map(&:first) + after
      end

      # The index into +points+ (an array of +[item, [lat, lon]]+ pairs)
      # closest to +position+ ([lat, lon]), and its distance in metres.
      def nearest(points, position)
        best_index = nil
        best_distance = nil

        points.each_with_index do |(_item, point_position), index|
          distance = Similarity::Geo.distance(point_position, position)
          if best_distance.nil? || distance < best_distance
            best_distance = distance
            best_index = index
          end
        end

        [best_index, best_distance]
      end

      def check_tolerance!(distance, tolerance, label)
        return if tolerance.nil? || distance <= tolerance

        raise ArgumentError,
              "the transplant #{label} is #{distance.round(1)}m from the route (tolerance #{tolerance}m)"
      end
    end
  end
end
