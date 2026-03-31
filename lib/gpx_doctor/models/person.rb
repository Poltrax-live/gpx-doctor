# frozen_string_literal: true

module GpxDoctor
  module Models
    Person = Struct.new(:name, :email, :link, keyword_init: true)
  end
end
