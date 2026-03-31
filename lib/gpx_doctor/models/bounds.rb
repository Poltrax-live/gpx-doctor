# frozen_string_literal: true

module GpxDoctor
  module Models
    Bounds = Struct.new(:minlat, :minlon, :maxlat, :maxlon, keyword_init: true)
  end
end
