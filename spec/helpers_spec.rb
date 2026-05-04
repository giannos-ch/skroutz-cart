require 'spec_helper'
require 'skroutz_cart/helpers'

RSpec.describe SkroutzCart::Helpers do
  describe '.parse_price' do
    it 'returns 0.0 for nil' do
      expect(described_class.parse_price(nil)).to eq(0.0)
    end

    it 'returns numeric values as floats' do
      expect(described_class.parse_price(12)).to eq(12.0)
      expect(described_class.parse_price(9.99)).to eq(9.99)
    end

    it 'parses a plain decimal string' do
      expect(described_class.parse_price('12.50')).to eq(12.50)
    end

    it 'strips the euro sign and whitespace' do
      expect(described_class.parse_price('€ 12.50')).to eq(12.50)
      expect(described_class.parse_price('€12.50')).to eq(12.50)
    end

    it 'parses European decimal format (comma as decimal separator)' do
      expect(described_class.parse_price('12,50')).to eq(12.50)
      expect(described_class.parse_price('9,99')).to eq(9.99)
    end

    it 'parses European thousands format' do
      expect(described_class.parse_price('1.234,50')).to eq(1234.50)
      expect(described_class.parse_price('1.000,00')).to eq(1000.00)
    end

    it 'handles strings with only whole numbers' do
      expect(described_class.parse_price('15')).to eq(15.0)
    end

    it 'returns 0.0 for empty string' do
      expect(described_class.parse_price('')).to eq(0.0)
    end
  end

  describe '.build_headers' do
    it 'includes standard headers' do
      headers = described_class.build_headers('my_cookie=abc')
      expect(headers['User-Agent']).to include('Mozilla')
      expect(headers['Accept']).to include('application/json')
      expect(headers['x-requested-with']).to eq('XMLHttpRequest')
    end

    it 'includes cookie when provided' do
      headers = described_class.build_headers('my_cookie=abc')
      expect(headers['Cookie']).to eq('my_cookie=abc')
    end

    it 'omits cookie when nil' do
      headers = described_class.build_headers(nil)
      expect(headers).not_to have_key('Cookie')
    end

    it 'omits cookie when empty string' do
      headers = described_class.build_headers('')
      expect(headers).not_to have_key('Cookie')
    end
  end
end
