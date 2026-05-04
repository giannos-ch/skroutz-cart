require 'uri'
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
      uri = URI.parse("#{Constants::BASE_URL}/s/#{sku_id}/filter_products.json")
      response = Helpers.fetch(uri, @headers)

      offers = []
      product_cards = response['product_cards'] || {}

      product_cards.each do |_, card|
        next unless card['ecommerce_available'] == true

        product = card['products']&.first
        next unless product

        price = Helpers.parse_price(card['price'])
        next if price <= 0

        shop_offer = ShopOffer.new(
          shop_id: card['shop_id'],
          shop_name: card['shop_name'] || "Shop #{card['shop_id']}",
          price: price,
          product_name: product['name'],
          product_id: product['id']
        )
        offers << shop_offer
      end

      offers.sort_by(&:price)
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
