require 'spec_helper'
require 'skroutz_cart/cache'
require 'tmpdir'
require 'uri'

RSpec.describe SkroutzCart::Cache do
  let(:uri) { URI.parse('https://www.example.com/api/data') }
  let(:tmpdir) { Dir.mktmpdir }

  before { allow(described_class).to receive(:dir).and_return(tmpdir) }
  after  { FileUtils.rm_rf(tmpdir) }

  describe '.path_for' do
    it 'generates a deterministic filename from the URI' do
      path = described_class.path_for(uri)
      expect(path).to start_with(tmpdir)
      expect(File.basename(path)).to match(/\A[\w.-]+\z/)
    end

    it 'includes the query string when present' do
      uri_with_query = URI.parse('https://www.example.com/api?foo=bar')
      path = described_class.path_for(uri_with_query)
      expect(path).to include('foo')
    end
  end

  describe '.write and .read' do
    it 'writes and reads back a JSON payload' do
      payload = { 'hello' => 'world', 'count' => 42 }
      described_class.write(uri, payload.to_json)
      result = described_class.read(uri)
      expect(result).to eq(payload)
    end

    it 'returns raw string when content is not valid JSON (e.g. HTML)' do
      html = '<html><body>hello</body></html>'
      described_class.write(uri, html)
      result = described_class.read(uri)
      expect(result).to eq(html)
    end

    it 'returns nil when no cache entry exists' do
      result = described_class.read(URI.parse('https://www.example.com/nonexistent'))
      expect(result).to be_nil
    end
  end

  describe '.clear' do
    it 'removes all cached files' do
      described_class.write(uri, '{"a":1}')
      described_class.clear
      expect(File.exist?(tmpdir)).to be(false)
    end
  end
end
