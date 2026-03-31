# frozen_string_literal: true

module GpxDoctor
  module Models
    Route = Struct.new(
      :name, :cmt, :desc, :src, :links, :number, :type, :points,
      keyword_init: true
    ) do
      def initialize(**)
        super
        self.links  ||= []
        self.points ||= []
      end
    end
  end
end
