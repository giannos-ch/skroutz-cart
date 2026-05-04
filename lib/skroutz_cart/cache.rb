require 'fileutils'
require 'json'

module SkroutzCart
  module Cache
    DEFAULT_DIR = File.join(__dir__, '..', '..', '.cache')

    def self.dir
      DEFAULT_DIR
    end

    def self.path_for(uri)
      key = "#{uri.host}#{uri.path}"
      key += "?#{uri.query}" if uri.query
      filename = key.gsub(/[^\w.-]/, '_')
      File.join(dir, filename)
    end

    def self.read(uri)
      file = path_for(uri)
      return nil unless File.exist?(file)

      raw = File.read(file)
      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def self.write(uri, body)
      FileUtils.mkdir_p(dir)
      File.write(path_for(uri), body)
    end

    def self.clear
      FileUtils.rm_rf(dir)
    end
  end
end
