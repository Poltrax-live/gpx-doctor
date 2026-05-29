# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GpxDoctor::Validator do
  let(:valid_gpx) { File.read(File.expand_path('../../fixtures/sample.gpx', __FILE__)) }

  def fixture(name)
    File.read(File.expand_path("../../fixtures/#{name}", __FILE__))
  end

  describe '.validate!' do
    context 'with a valid GPX 1.1 file' do
      it 'returns true' do
        expect(described_class.validate!(valid_gpx)).to be true
      end
    end

    context 'with a valid GPX 1.0 file' do
      it 'returns true' do
        expect(described_class.validate!(fixture('gpx10.gpx'))).to be true
      end
    end

    context 'with an empty string' do
      it 'raises InvalidGpxError' do
        expect { described_class.validate!('') }
          .to raise_error(GpxDoctor::InvalidGpxError)
      end
    end

    context 'with non-XML content' do
      it 'raises InvalidGpxError' do
        expect { described_class.validate!(fixture('not_xml.txt')) }
          .to raise_error(GpxDoctor::InvalidGpxError, /Invalid XML|Root element/)
      end
    end

    context 'with malformed XML' do
      it 'raises InvalidGpxError' do
        expect { described_class.validate!('<gpx version="1.1"><unclosed>') }
          .to raise_error(GpxDoctor::InvalidGpxError, /Invalid XML/)
      end
    end

    context 'with a wrong root element' do
      it 'raises InvalidGpxError mentioning <gpx>' do
        expect { described_class.validate!(fixture('wrong_root.xml')) }
          .to raise_error(GpxDoctor::InvalidGpxError, /Root element must be <gpx>/)
      end
    end

    context 'with an unsupported GPX version' do
      it 'raises InvalidGpxError mentioning the version' do
        expect { described_class.validate!(fixture('unsupported_version.gpx')) }
          .to raise_error(GpxDoctor::InvalidGpxError, /Unsupported GPX version/)
      end
    end

    context 'with an XXE attack payload (DOCTYPE + external entity)' do
      it 'raises InvalidGpxError before parsing' do
        expect { described_class.validate!(fixture('xxe_attack.gpx')) }
          .to raise_error(GpxDoctor::InvalidGpxError, /DOCTYPE/)
      end
    end

    context 'with a billion-laughs entity bomb (DOCTYPE)' do
      it 'raises InvalidGpxError before parsing' do
        expect { described_class.validate!(fixture('billion_laughs.gpx')) }
          .to raise_error(GpxDoctor::InvalidGpxError, /DOCTYPE/)
      end
    end
  end
end
