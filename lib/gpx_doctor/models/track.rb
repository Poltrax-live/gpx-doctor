# frozen_string_literal: true

module GpxDoctor
  module Models
    Track = Struct.new(
      :name, :cmt, :desc, :src, :links, :number, :type, :segments,
      keyword_init: true
    ) do
      def initialize(**)
        super
        self.links    ||= []
        self.segments ||= []
      end

      def points
        segments.flat_map(&:points)
      end
    end
  end
end
