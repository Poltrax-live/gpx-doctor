# frozen_string_literal: true

module GpxDoctor
  module UnitConverter
    METERS_TO_FEET = 3.28084
    METERS_TO_MILES = 0.000621371
    KILOMETERS_TO_MILES = 0.621371

    module_function

    # Convert meters to the configured unit system
    # Returns feet for imperial, meters for metric
    def convert_distance(meters, unit_system = :metric)
      return meters if unit_system == :metric
      meters * METERS_TO_FEET
    end

    # Convert meters to the configured unit system
    # Returns feet for imperial, meters for metric
    def convert_elevation(meters, unit_system = :metric)
      return meters if unit_system == :metric
      meters * METERS_TO_FEET
    end

    # Convert kilometers to the configured unit system
    # Returns miles for imperial, kilometers for metric
    def convert_cumulative_distance(kilometers, unit_system = :metric)
      return kilometers if unit_system == :metric
      kilometers * KILOMETERS_TO_MILES
    end
  end
end
