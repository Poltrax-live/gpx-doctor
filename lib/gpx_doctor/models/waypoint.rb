# frozen_string_literal: true

module GpxDoctor
  module Models
    class Waypoint
      FIELDS = %i[
        lat lon ele time magvar geoidheight name cmt desc src links
        sym type fix sat hdop vdop pdop ageofdgpsdata dgpsid
      ].freeze

      attr_accessor(*FIELDS)

      def initialize(**attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
        @links ||= []
      end

      def to_h
        FIELDS.each_with_object({}) do |field, hash|
          value = public_send(field)
          hash[field] = value unless value.nil?
        end
      end
    end
  end
end
