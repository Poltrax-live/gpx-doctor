# frozen_string_literal: true

module GpxDoctor
  class Transplant
    # Grafts a transplant onto a route given as a plain array of points.
    #
    #   # route: n1, n2, ..., n9 — m1 sits close to n2, m3 close to n8
    #   GpxDoctor::Transplant::Coordinates.graft(route, transplant) # => [n1, m1, m2, m3, n9]
    #
    # Both +route+ and +transplant+ accept the same point formats as
    # {Similarity#compare}: a +Waypoint+ (or anything else answering to
    # +lat+/+lon+, +latitude+/+longitude+ or +x+/+y+, such as a PostGIS
    # point), a +[lat, lon]+ pair, or a hash keyed by +lat+/+lon+,
    # +latitude+/+longitude+ or +x+/+y+ (string or symbol keys).
    #
    # The returned array holds the original point objects/values — unmatched
    # ones from +route+ plus every one of +transplant+ — never reconstructed
    # coordinate pairs.
    class Coordinates
      class << self
        # +tolerance+ is the furthest, in metres, the transplant's start and
        # end may sit from +route+; pass +nil+ to always graft onto the
        # nearest points regardless of distance.
        #
        # +coordinate_order+ applies to bare numeric pairs only; pass
        # +:lon_lat+ for PostGIS/GeoJSON style [lon, lat] coordinates.
        def graft(route, transplant, tolerance: Transplant::DEFAULT_TOLERANCE, coordinate_order: :lat_lon)
          new(route, transplant, tolerance: tolerance, coordinate_order: coordinate_order).graft
        end
      end

      def initialize(route, transplant, tolerance: Transplant::DEFAULT_TOLERANCE, coordinate_order: :lat_lon)
        @route = Array(route)
        @transplant = Array(transplant)
        @tolerance = tolerance
        @coordinate_order = coordinate_order
      end

      def graft
        raise ArgumentError, 'the route holds no points' if @route.empty?
        raise ArgumentError, 'the transplant holds no points' if @transplant.empty?

        Matcher.splice(pairs(@route), pairs(@transplant), tolerance: @tolerance)
      end

      private

      def pairs(points)
        points.map { |point| [point, Similarity::PointExtractor.position(point, @coordinate_order)] }
      end
    end
  end
end
