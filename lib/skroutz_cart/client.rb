require 'uri'
require 'cgi'
require 'json'
require_relative 'constants'
require_relative 'helpers'
require_relative 'models/cart_item'
require_relative 'models/shop_offer'

module SkroutzCart
  class Client
    def initialize(cookie)
      @cookie = cookie
      @headers = Helpers.build_headers(cookie)
    end

    def fetch_cart
      uri = URI.parse("#{Constants::BASE_URL}/cart/line_items.json")
      response = Helpers.fetch(uri, @headers, cache: false)

      items = response.dig('cart', 'line_items') || {}
      items.map do |_, item|
        CartItem.new(
          item['sku_id'],
          item['quantity'] || 1
        )
      end
    end

    def fetch_shop_offers(sku_id)
      uri = URI.parse("#{Constants::BASE_URL}/s/#{sku_id}/shops_list")
      headers = @headers.merge(
        'Accept' => 'text/html, application/xhtml+xml',
        'turbo-frame' => 'shops-list-frame'
      )
      html = Helpers.fetch_html(uri, headers)
      return [] unless html

      html = html.dup.force_encoding('UTF-8')

      offers = {}
      html.split(/<li id="shop-/).drop(1).each do |card|
        shop_id    = card[/data-shop-id="(\d+)"/, 1]
        price      = card[/data-raw-price="([\d.]+)"/, 1]&.to_f
        product_id = card[%r{data-product-url="/products/show/(\d+)"}, 1] || card[/data-card-id="(\d+)"/, 1]
        next unless shop_id && product_id && price && price > 0

        shop_name = card[%r{/shop/\d+/([^/"#?]+)}, 1]&.gsub('-', ' ') || "Shop #{shop_id}"
        gtag = card[/gtag-sku-value="(\{.+?\})"/, 1]
        product_name = gtag && (JSON.parse(CGI.unescapeHTML(gtag))['name'] rescue nil)

        existing = offers[shop_id]
        next if existing && existing.price <= price

        offers[shop_id] = ShopOffer.new(
          shop_id: shop_id.to_i,
          shop_name: shop_name,
          price: price,
          product_name: product_name,
          product_id: product_id.to_i
        )
      end

      offers.values.sort_by(&:price)
    end

    def fetch_csrf_token
      uri = URI.parse("#{Constants::BASE_URL}/")
      html = Helpers.fetch_html(uri, @headers, cache: false)
      return nil unless html

      match = html.match(/<meta name="csrf-token" content="([^"]+)"/)
      match ? match[1] : nil
    end

    def clear_cart(csrf_token)
      uri = URI.parse("#{Constants::BASE_URL}/cart/clear.html")
      headers = @headers.merge(
        'Content-Type' => 'application/json',
        'Origin' => Constants::BASE_URL,
        'x-csrf-token' => csrf_token
      )
      Helpers.post(uri, headers, {})
    end

    def add_to_cart(sku_id, product_id, csrf_token)
      uri = URI.parse("#{Constants::BASE_URL}/cart/add/#{sku_id}.json")
      headers = @headers.merge(
        'Content-Type' => 'application/json',
        'Origin' => Constants::BASE_URL,
        'x-csrf-token' => csrf_token
      )
      body = {
        product_id: product_id,
        assortments: {},
        from: 'sku_product_cards',
        offering_type: nil,
        express: nil,
        recommendation_source_sku_id: nil
      }
      Helpers.post(uri, headers, body)
    end

    def change_quantity(line_item_id, quantity, csrf_token)
      uri = URI.parse("#{Constants::BASE_URL}/cart/change_line_item_quantity.json")
      headers = @headers.merge(
        'Content-Type' => 'application/json',
        'Origin' => Constants::BASE_URL,
        'x-csrf-token' => csrf_token
      )
      body = {
        line_item_id: line_item_id.to_s,
        quantity: quantity,
        from_sku_page: true
      }
      Helpers.post(uri, headers, body)
    end
  end
end
