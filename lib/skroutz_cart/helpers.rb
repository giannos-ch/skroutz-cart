require 'net/http'
require 'uri'
require 'json'
require 'openssl'

require_relative 'constants'
require_relative 'cache'

module SkroutzCart
  module Helpers
    def self.parse_price(price_str)
      return 0.0 unless price_str
      return price_str.to_f if price_str.is_a?(Numeric)

      cleaned = price_str.to_s.gsub(/[€\s]/, '')

      cleaned = if cleaned.match?(/\d{1,3}(\.\d{3})+,\d+/)
                  # European format with thousands: "1.234,50" -> "1234.50"
                  cleaned.gsub('.', '').gsub(',', '.')
                elsif cleaned.match?(/,\d{1,2}$/)
                  # European decimal only: "12,50" -> "12.50"
                  cleaned.gsub(',', '.')
                else
                  # Standard or already dot-decimal: remove any stray commas
                  cleaned.gsub(',', '')
                end

      cleaned.to_f
    end

    def self.build_headers(cookie)
      headers = {
        'User-Agent' => Constants::USER_AGENT,
        'Accept' => Constants::ACCEPT,
        'Referer' => "#{Constants::BASE_URL}/",
        'x-requested-with' => 'XMLHttpRequest'
      }
      headers['Cookie'] = cookie if cookie && !cookie.empty?
      headers
    end

    def self.fetch(uri, headers, cache: true)
      if cache
        cached = Cache.read(uri)
        return cached if cached
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri, headers)
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        Cache.write(uri, response.body)
        JSON.parse(response.body)
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response['location'])
        fetch(redirect_uri, headers)
      else
        puts "Error: HTTP #{response.code}"
        puts response.body[0..500]
        exit 1
      end
    end

    def self.fetch_html(uri, headers, cache: true)
      if cache
        cached = Cache.read(uri)
        return cached if cached
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri, headers)
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        Cache.write(uri, response.body)
        response.body
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response['location'])
        fetch_html(redirect_uri, headers)
      end
    end

    def self.post(uri, headers, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri, headers)
      request.body = body.to_json
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        begin
          JSON.parse(response.body)
        rescue StandardError
          {}
        end
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response['location'])
        post(redirect_uri, headers, body)
      else
        puts "Error: HTTP #{response.code} - #{response.body[0..200]}"
        nil
      end
    end
  end
end
