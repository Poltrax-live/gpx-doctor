# frozen_string_literal: true

module GpxDoctor
  module Models
    Metadata = Struct.new(
      :name, :desc, :author, :copyright, :links, :time, :keywords, :bounds,
      keyword_init: true
    ) do
      def initialize(**)
        super
        self.links ||= []
      end
    end
  end
end
