# frozen_string_literal: true

module GpxDoctor
  module Models
    Email = Struct.new(:id, :domain, keyword_init: true) do
      def to_s
        "#{id}@#{domain}"
      end
    end
  end
end
