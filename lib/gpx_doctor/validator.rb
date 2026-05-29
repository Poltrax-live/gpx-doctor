# frozen_string_literal: true

require 'nokogiri'

module GpxDoctor
  class Validator
    ALLOWED_VERSIONS = %w[1.0 1.1].freeze

    # Matches a DOCTYPE declaration anywhere in the string (case-insensitive).
    # DOCTYPE is rejected entirely because it can carry external-entity
    # references (XXE) or internal entity bombs (billion-laughs).
    DOCTYPE_PATTERN = /<!DOCTYPE/i.freeze

    class << self
      def validate!(xml_string)
        new(xml_string).validate!
      end
    end

    def initialize(xml_string)
      @xml_string = xml_string
    end

    # Raises GpxDoctor::InvalidGpxError if the input is not a valid, safe GPX document.
    def validate!
      reject_doctype!
      doc = parse_xml!
      validate_root!(doc)
      validate_version!(doc)
      true
    end

    private

    def reject_doctype!
      return unless @xml_string.match?(DOCTYPE_PATTERN)

      raise InvalidGpxError, 'DOCTYPE declarations are not allowed'
    end

    def parse_xml!
      doc = Nokogiri::XML(@xml_string) { |config| config.nonet }
      return doc if doc.errors.empty?

      raise InvalidGpxError, "Invalid XML: #{doc.errors.map(&:message).join('; ')}"
    end

    def validate_root!(doc)
      root = doc.root
      return if root&.name == 'gpx'

      raise InvalidGpxError, 'Root element must be <gpx>'
    end

    def validate_version!(doc)
      version = doc.root['version']
      return if ALLOWED_VERSIONS.include?(version)

      raise InvalidGpxError,
            "Unsupported GPX version: #{version.inspect}. Supported versions: #{ALLOWED_VERSIONS.join(', ')}"
    end
  end
end
