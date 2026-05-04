require_relative 'optimizer'
require_relative 'presenter'

module SkroutzCart
  module CartRunner
    def self.find_cheapest(client, options = {})
      puts 'Fetching cart items...'
      cart_items = client.fetch_cart

      if cart_items.empty?
        puts 'Cart is empty!'
        return
      end

      puts "Found #{cart_items.length} item(s) in cart"
      puts

      sku_quantities = {}
      sku_offers_map = {}

      puts 'Fetching shop offers for each SKU...'
      cart_items.each do |item|
        print "  SKU #{item.sku_id}... "
        $stdout.flush

        sku_quantities[item.sku_id] = item.quantity
        offers = client.fetch_shop_offers(item.sku_id)

        if offers.empty?
          puts 'no offers found'
          next
        end

        puts "#{offers.length} offers (cheapest: €#{'%.2f' % offers.first.price})"
        sku_offers_map[item.sku_id] = offers
      end

      puts

      if sku_offers_map.empty?
        puts 'No offers found for any item.'
        return
      end

      missing = cart_items.map(&:sku_id) - sku_offers_map.keys
      unless missing.empty?
        puts "Warning: no offers found for SKU(s): #{missing.join(', ')}"
        puts
      end

      sku_ids = sku_offers_map.keys

      assignment = Optimizer.run(sku_ids, sku_offers_map, sku_quantities, algorithm: options[:algorithm] || :dp)

      Presenter.print_result(assignment, sku_ids, sku_quantities)

      confirm_and_add_to_cart(client, assignment, sku_ids, sku_quantities, options[:confirm], sku_offers_map)
    end

    def self.add_items_to_cart(client, assignment, sku_ids, sku_quantities)
      puts 'Fetching CSRF token...'
      csrf_token = client.fetch_csrf_token

      unless csrf_token
        puts 'Error: could not fetch CSRF token. Try refreshing your cookie.'
        return
      end

      puts 'Clearing cart...'
      client.clear_cart(csrf_token)
      puts 'Cart cleared.'
      puts
      puts 'Adding items to cart...'
      errors = []

      assignment.each_with_index do |offer, i|
        sku_id = sku_ids[i]
        qty    = sku_quantities[sku_id]
        print "  #{offer.product_name.to_s[0..40]}... "
        $stdout.flush

        unless offer.product_id
          puts 'skipped (no product_id)'
          errors << sku_id
          next
        end

        result = client.add_to_cart(sku_id, offer.product_id, csrf_token)

        unless result
          puts 'FAILED'
          errors << sku_id
          next
        end

        if qty != 1
          line_item_id = result.dig('line_items_info', 0, 'line_item', 'id')

          if line_item_id
            client.change_quantity(line_item_id, qty, csrf_token)
            puts "added (qty: #{qty})"
          else
            puts "added (WARNING: could not set qty #{qty} — line_item_id not found in response)"
          end
        else
          puts 'added'
        end
      end

      puts
      if errors.empty?
        puts 'All items added to cart successfully.'
      else
        puts "Done with errors. Failed SKU(s): #{errors.join(', ')}"
      end
    end

    def self.confirm_and_add_to_cart(client, assignment, sku_ids, sku_quantities, confirm, sku_offers_map)
      return unless assignment

      if confirm == true
        puts
        puts '(--yes) Adding items to cart...'
        puts
        add_items_to_cart(client, assignment, sku_ids, sku_quantities)
        return
      elsif confirm == false
        puts
        puts '(--no) Exiting. No changes made to your cart.'
        return
      end

      loop do
        puts
        puts '[1] Add to cart'
        puts '[2] Show SKU cost breakdown'
        puts '[3] Exit'
        print 'Choose: '
        $stdout.flush
        choice = $stdin.gets&.strip

        case choice
        when '1'
          puts
          add_items_to_cart(client, assignment, sku_ids, sku_quantities)
          break
        when '2'
          Presenter.show_sku_breakdown(assignment, sku_ids, sku_quantities, sku_offers_map)
        when '3', nil
          puts 'Exiting. No changes made to your cart.'
          break
        else
          puts 'Invalid choice — enter 1, 2, or 3.'
        end
      end
    end
  end
end
