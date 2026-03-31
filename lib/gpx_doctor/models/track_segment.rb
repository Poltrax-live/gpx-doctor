# frozen_string_literal: true

module GpxDoctor
  module Models
    TrackSegment = Struct.new(:points, keyword_init: true) do
      def initialize(**)
        super
        self.points ||= []
      end
    end
  end
end
