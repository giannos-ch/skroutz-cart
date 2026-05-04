require 'spec_helper'
require 'skroutz_cart/cli'

RSpec.describe SkroutzCart::CLI do
  describe '.parse_args' do
    it 'reads cookie from --cookie flag' do
      opts = described_class.parse_args(['--cookie', 'my_cookie=abc'])
      expect(opts[:cookie]).to eq('my_cookie=abc')
    end

    it 'reads cookie from -c short flag' do
      opts = described_class.parse_args(['-c', 'my_cookie=abc'])
      expect(opts[:cookie]).to eq('my_cookie=abc')
    end

    it 'sets algorithm to :dp' do
      opts = described_class.parse_args(['-c', 'x', '--algorithm', 'dp'])
      expect(opts[:algorithm]).to eq(:dp)
    end

    it 'sets algorithm to :bnb' do
      opts = described_class.parse_args(['-c', 'x', '-a', 'bnb'])
      expect(opts[:algorithm]).to eq(:bnb)
    end

    it 'sets confirm to true with --yes' do
      opts = described_class.parse_args(['-c', 'x', '--yes'])
      expect(opts[:confirm]).to be(true)
    end

    it 'sets confirm to false with --no' do
      opts = described_class.parse_args(['-c', 'x', '--no'])
      expect(opts[:confirm]).to be(false)
    end

    it 'sets verbose flag' do
      opts = described_class.parse_args(['-c', 'x', '--verbose'])
      expect(opts[:verbose]).to be(true)
    end

    it 'reads cookie from --cookie-file' do
      Tempfile.create('cookie') do |f|
        f.write('  file_cookie=xyz  ')
        f.flush
        opts = described_class.parse_args(['--cookie-file', f.path])
        expect(opts[:cookie]).to eq('file_cookie=xyz')
      end
    end

    it 'exits with error for missing cookie file' do
      expect do
        described_class.parse_args(['--cookie-file', '/no/such/file.txt'])
      end.to raise_error(SystemExit)
    end

    it 'exits with error for invalid algorithm value' do
      expect do
        described_class.parse_args(['-c', 'x', '--algorithm', 'bogus'])
      end.to raise_error(SystemExit)
    end
  end
end
