# frozen_string_literal: true

module GpxDoctor
  module Models
    class Waypoint
      FIELDS = %i[
        lat lon ele time magvar geoidheight name cmt desc src links
        sym type fix sat hdop vdop pdop ageofdgpsdata dgpsid
      ].freeze

      STATISTICS_FIELDS = %i[distance_to_next elevation_change direction].freeze

      attr_accessor(*STATISTICS_FIELDS)

      attr_accessor(*FIELDS)

      def initialize(**attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
        @links ||= []
      end

      def to_h
        hash = FIELDS.each_with_object({}) do |field, h|
          value = public_send(field)
          h[field] = value unless value.nil?
        end
        STATISTICS_FIELDS.each do |field|
          value = public_send(field)
          hash[field] = value unless value.nil?
        end
        hash
      end
    end
  end
end
