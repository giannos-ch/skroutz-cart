require_relative 'constants'
require_relative 'optimizer'

module SkroutzCart
  module Presenter
    def self.print_result(assignment, sku_ids, sku_quantities)
      return puts 'Could not find a valid assignment.' if assignment.nil? || assignment.any?(&:nil?)

      shop_data = {}
      assignment.each_with_index do |offer, i|
        sku_id = sku_ids[i]
        qty = sku_quantities[sku_id]
        shop_data[offer.shop_id] ||= { name: offer.shop_name, items: [] }
        shop_data[offer.shop_id][:items] << {
          sku_id: sku_id,
          product_name: offer.product_name,
          price: offer.price,
          qty: qty,
          line_total: offer.price * qty
        }
      end

      puts '=' * 70
      puts 'OPTIMAL CART ASSIGNMENT'
      puts '=' * 70
      puts

      grand_total = 0.0

      shop_data.each do |_shop_id, data|
        subtotal = data[:items].sum { |i| i[:line_total] }
        shipping = subtotal < Constants::MIN_SHIPPING_THRESHOLD ? Constants::SHIPPING_COST : 0.0
        shop_total = subtotal + shipping

        puts "Shop: #{data[:name]}"
        puts '-' * 50
        data[:items].each do |item|
          qty_str = item[:qty] > 1 ? " x#{item[:qty]}" : ''
          puts format('  %-35s €%.2f%s', item[:product_name].to_s[0..34], item[:price], qty_str)
        end
        puts "  Subtotal: €#{'%.2f' % subtotal}"
        if shipping > 0
          puts "  Shipping: €#{'%.2f' % shipping} (order under €#{Constants::MIN_SHIPPING_THRESHOLD})"
        else
          puts '  Shipping: free'
        end
        puts "  Shop total: €#{'%.2f' % shop_total}"
        puts

        grand_total += shop_total
      end

      puts '=' * 70
      puts "GRAND TOTAL: €#{'%.2f' % grand_total}"
      puts '=' * 70
    end

    def self.show_sku_breakdown(assignment, sku_ids, sku_quantities, sku_offers_map)
      total_cost = Optimizer.compute_total_cost(assignment, sku_ids, sku_quantities)

      puts
      puts 'Computing per-SKU marginal costs...'

      rows = sku_ids.each_with_index.map do |sku_id, i|
        offer     = assignment[i]
        min_price = sku_offers_map[sku_id].first.price

        remaining_ids = sku_ids.reject { |id| id == sku_id }
        cost_without =
          if remaining_ids.empty?
            0.0
          else
            remaining_map    = sku_offers_map.reject { |id, _| id == sku_id }
            remaining_assign = Optimizer.subset_dp(remaining_ids, remaining_map, sku_quantities)
            Optimizer.compute_total_cost(remaining_ids.map { |id| remaining_assign[id] }, remaining_ids, sku_quantities)
          end

        marginal = total_cost - cost_without
        diff     = marginal - min_price * sku_quantities[sku_id]
        { sku_id: sku_id,
          product_name: offer.product_name.to_s,
          qty: sku_quantities[sku_id],
          min_price: min_price,
          actual_price: offer.price,
          marginal_cost: marginal,
          diff: diff.abs < 0.001 ? nil : diff }
      end

      puts
      puts format('%-14s %-34s %3s %8s %8s %9s %6s',
                  'SKU', 'Product', 'Qty', 'Min', 'Cart', 'Marginal', 'Diff')
      puts '-' * 90
      rows.each do |r|
        puts format('%-14s %-34s %3s %8s %8s %9s %6s',
                    r[:sku_id],
                    r[:product_name][0..33],
                    r[:qty] > 1 ? "x#{r[:qty]}" : '',
                    '€%.2f' % r[:min_price],
                    '€%.2f' % r[:actual_price],
                    '€%.2f' % r[:marginal_cost],
                    r[:diff] ? '€%.2f' % r[:diff] : '')
      end
      puts
    end
  end
end
