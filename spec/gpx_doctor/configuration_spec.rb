# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'sets elevation_server to false' do
      expect(config.elevation_server).to eq(false)
    end

    it 'sets elevation_server_url to nil' do
      expect(config.elevation_server_url).to be_nil
    end

    it 'sets elevation_server_user to nil' do
      expect(config.elevation_server_user).to be_nil
    end

    it 'sets elevation_server_password to nil' do
      expect(config.elevation_server_password).to be_nil
    end

    it 'sets unit_system to :metric' do
      expect(config.unit_system).to eq(:metric)
    end
  end

  describe 'custom values via configure block' do
    before do
      GpxDoctor.configure do |c|
        c.elevation_server          = true
        c.elevation_server_url      = 'https://elevation.example.com'
        c.elevation_server_user     = 'user'
        c.elevation_server_password = 'secret'
        c.unit_system               = :imperial
      end
    end

    it 'stores elevation_server' do
      expect(GpxDoctor.configuration.elevation_server).to eq(true)
    end

    it 'stores elevation_server_url' do
      expect(GpxDoctor.configuration.elevation_server_url).to eq('https://elevation.example.com')
    end

    it 'stores elevation_server_user' do
      expect(GpxDoctor.configuration.elevation_server_user).to eq('user')
    end

    it 'stores elevation_server_password' do
      expect(GpxDoctor.configuration.elevation_server_password).to eq('secret')
    end

    it 'stores unit_system' do
      expect(GpxDoctor.configuration.unit_system).to eq(:imperial)
    end
  end

  describe '.reset_configuration!' do
    before do
      GpxDoctor.configure do |c|
        c.elevation_server_url = 'https://example.com'
        c.unit_system = :imperial
      end
      GpxDoctor.reset_configuration!
    end

    it 'resets to defaults' do
      expect(GpxDoctor.configuration.elevation_server_url).to be_nil
      expect(GpxDoctor.configuration.elevation_server).to eq(false)
      expect(GpxDoctor.configuration.unit_system).to eq(:metric)
    end
  end

  describe 'unit_system validation' do
    it 'accepts :metric' do
      expect { config.unit_system = :metric }.not_to raise_error
      expect(config.unit_system).to eq(:metric)
    end

    it 'accepts :imperial' do
      expect { config.unit_system = :imperial }.not_to raise_error
      expect(config.unit_system).to eq(:imperial)
    end

    it 'rejects invalid values' do
      expect { config.unit_system = :invalid }.to raise_error(ArgumentError, "unit_system must be :metric or :imperial")
    end

    it 'rejects string values' do
      expect { config.unit_system = 'metric' }.to raise_error(ArgumentError, "unit_system must be :metric or :imperial")
    end

    it 'rejects nil' do
      expect { config.unit_system = nil }.to raise_error(ArgumentError, "unit_system must be :metric or :imperial")
    end
  end
end
