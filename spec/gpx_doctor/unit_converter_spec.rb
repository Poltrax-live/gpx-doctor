# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::UnitConverter do
  describe '.convert_distance' do
    it 'returns meters for metric system' do
      result = described_class.convert_distance(100.0, :metric)
      expect(result).to eq(100.0)
    end

    it 'converts meters to feet for imperial system' do
      result = described_class.convert_distance(100.0, :imperial)
      expect(result).to be_within(0.01).of(328.084)
    end

    it 'defaults to metric when no unit system specified' do
      result = described_class.convert_distance(100.0)
      expect(result).to eq(100.0)
    end

    it 'handles zero distance' do
      expect(described_class.convert_distance(0.0, :metric)).to eq(0.0)
      expect(described_class.convert_distance(0.0, :imperial)).to eq(0.0)
    end

    it 'handles negative distance' do
      expect(described_class.convert_distance(-100.0, :metric)).to eq(-100.0)
      expect(described_class.convert_distance(-100.0, :imperial)).to be_within(0.01).of(-328.084)
    end
  end

  describe '.convert_elevation' do
    it 'returns meters for metric system' do
      result = described_class.convert_elevation(50.0, :metric)
      expect(result).to eq(50.0)
    end

    it 'converts meters to feet for imperial system' do
      result = described_class.convert_elevation(50.0, :imperial)
      expect(result).to be_within(0.01).of(164.042)
    end

    it 'defaults to metric when no unit system specified' do
      result = described_class.convert_elevation(50.0)
      expect(result).to eq(50.0)
    end

    it 'handles zero elevation' do
      expect(described_class.convert_elevation(0.0, :metric)).to eq(0.0)
      expect(described_class.convert_elevation(0.0, :imperial)).to eq(0.0)
    end

    it 'handles negative elevation (descent)' do
      expect(described_class.convert_elevation(-50.0, :metric)).to eq(-50.0)
      expect(described_class.convert_elevation(-50.0, :imperial)).to be_within(0.01).of(-164.042)
    end
  end

  describe '.convert_cumulative_distance' do
    it 'returns kilometers for metric system' do
      result = described_class.convert_cumulative_distance(10.0, :metric)
      expect(result).to eq(10.0)
    end

    it 'converts kilometers to miles for imperial system' do
      result = described_class.convert_cumulative_distance(10.0, :imperial)
      expect(result).to be_within(0.001).of(6.21371)
    end

    it 'defaults to metric when no unit system specified' do
      result = described_class.convert_cumulative_distance(10.0)
      expect(result).to eq(10.0)
    end

    it 'handles zero distance' do
      expect(described_class.convert_cumulative_distance(0.0, :metric)).to eq(0.0)
      expect(described_class.convert_cumulative_distance(0.0, :imperial)).to eq(0.0)
    end

    it 'handles small distances accurately' do
      result = described_class.convert_cumulative_distance(1.0, :imperial)
      expect(result).to be_within(0.00001).of(0.621371)
    end
  end

  describe 'conversion constants' do
    it 'has correct meters to feet conversion' do
      expect(described_class::METERS_TO_FEET).to eq(3.28084)
    end

    it 'has correct meters to miles conversion' do
      expect(described_class::METERS_TO_MILES).to eq(0.000621371)
    end

    it 'has correct kilometers to miles conversion' do
      expect(described_class::KILOMETERS_TO_MILES).to eq(0.621371)
    end
  end
end
