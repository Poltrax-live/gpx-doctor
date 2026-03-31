# frozen_string_literal: true

module GpxDoctor
  module Models
    Link = Struct.new(:href, :text, :type, keyword_init: true)
  end
end
