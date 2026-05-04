require_relative 'constants'
require_relative 'models/shop_offer'

module SkroutzCart
  module Optimizer
    # ---------------------------------------------------------------------------
    # Branch-and-bound
    # ---------------------------------------------------------------------------

    # Precompute suffix[i] = sum of cheapest prices for SKUs i..end.
    def self.build_min_suffix(candidates, sku_ids, sku_quantities)
      n = sku_ids.length
      suffix = Array.new(n + 1, 0.0)
      (n - 1).downto(0) do |i|
        qty = sku_quantities[sku_ids[i]]
        suffix[i] = suffix[i + 1] + candidates[i].first.price * qty
      end
      suffix
    end

    # For each shop, the last SKU index where it appears.
    def self.build_shop_last_index(candidates)
      result = {}
      candidates.each_with_index do |offers, i|
        offers.each { |o| result[o.shop_id] = i }
      end
      result
    end

    def self.enumerate(candidates, idx, assign, sku_ids, sku_quantities, best,
                       price_sum, min_suffix, shop_subtotals, shop_last_index)
      if idx == sku_ids.length
        total = shop_subtotals.sum do |_, sub|
          sub < Constants::MIN_SHIPPING_THRESHOLD ? sub + Constants::SHIPPING_COST : sub
        end
        if total < best[:cost]
          best[:cost] = total
          best[:assignment] = assign.dup
        end
        return
      end

      definite_shipping = 0.0
      shop_subtotals.each do |shop_id, sub|
        next if sub >= Constants::MIN_SHIPPING_THRESHOLD

        definite_shipping += Constants::SHIPPING_COST if (shop_last_index[shop_id] || -1) < idx
      end

      return if price_sum + min_suffix[idx] + definite_shipping >= best[:cost]

      qty = sku_quantities[sku_ids[idx]]
      candidates[idx].each do |offer|
        assign[idx] = offer
        prev = shop_subtotals[offer.shop_id] || 0.0
        shop_subtotals[offer.shop_id] = prev + offer.price * qty
        enumerate(candidates, idx + 1, assign, sku_ids, sku_quantities, best,
                  price_sum + offer.price * qty, min_suffix, shop_subtotals, shop_last_index)
        prev == 0.0 ? shop_subtotals.delete(offer.shop_id) : shop_subtotals[offer.shop_id] = prev
      end
    end

    def self.branch_and_bound(sku_ids, sku_offers_map, sku_quantities)
      sorted_ids = sku_ids.sort_by { |id| -sku_offers_map[id].length }
      candidates = sorted_ids.map { |id| sku_offers_map[id] }

      total_combinations = candidates.map(&:length).reduce(1, :*)
      puts "Evaluating up to #{total_combinations} combination(s) (branch-and-bound with pruning)..."
      puts

      min_suffix      = build_min_suffix(candidates, sorted_ids, sku_quantities)
      shop_last_index = build_shop_last_index(candidates)

      best = { cost: Float::INFINITY, assignment: nil }
      enumerate(candidates, 0, Array.new(sorted_ids.length), sorted_ids, sku_quantities,
                best, 0.0, min_suffix, {}, shop_last_index)

      return nil unless best[:assignment]

      assign_by_sku = sorted_ids.each_with_index.to_h { |id, i| [id, best[:assignment][i]] }
      sku_ids.map { |id| assign_by_sku[id] }
    end

    # ---------------------------------------------------------------------------
    # Subset partition DP
    # ---------------------------------------------------------------------------

    def self.subset_dp(sku_ids, sku_offers_map, sku_quantities)
      n = sku_ids.length
      return {} if n == 0

      shop_item_offers = {}
      sku_ids.each_with_index do |sku_id, idx|
        sku_offers_map[sku_id].each do |offer|
          shop_item_offers[offer.shop_id] ||= {}
          shop_item_offers[offer.shop_id][idx] ||= offer
        end
      end

      inf = Float::INFINITY
      best_cost   = Array.new(1 << n, inf)
      best_shop   = Array.new(1 << n, nil)
      best_offers = Array.new(1 << n, nil)

      shop_item_offers.each do |shop_id, item_map|
        shop_mask = item_map.keys.reduce(0) { |m, i| m | (1 << i) }

        sub = shop_mask
        while sub > 0
          total = 0.0
          n.times { |i| total += item_map[i].price * sku_quantities[sku_ids[i]] if (sub >> i) & 1 == 1 }
          shipping = total < Constants::MIN_SHIPPING_THRESHOLD ? Constants::SHIPPING_COST : 0.0
          cost = total + shipping
          if cost < best_cost[sub]
            best_cost[sub]   = cost
            best_shop[sub]   = shop_id
            offers_snap      = {}
            n.times { |i| offers_snap[i] = item_map[i] if (sub >> i) & 1 == 1 }
            best_offers[sub] = offers_snap
          end
          sub = (sub - 1) & shop_mask
        end
      end

      dp_cost   = Array.new(1 << n, inf)
      dp_choice = Array.new(1 << n, nil)
      dp_cost[0] = 0.0

      (1..(1 << n) - 1).each do |mask|
        low_bit  = mask & (-mask)
        rest     = mask ^ low_bit
        sub_rest = rest
        loop do
          sub = sub_rest | low_bit
          c = best_cost[sub]
          if c < inf
            total = dp_cost[mask ^ sub] + c
            if total < dp_cost[mask]
              dp_cost[mask]   = total
              dp_choice[mask] = sub
            end
          end
          break if sub_rest == 0

          sub_rest = (sub_rest - 1) & rest
        end
      end

      assignment = {}
      mask = (1 << n) - 1
      while mask > 0
        sub = dp_choice[mask]
        break unless sub

        best_offers[sub].each { |idx, offer| assignment[sku_ids[idx]] = offer }
        mask ^= sub
      end

      assignment
    end

    # ---------------------------------------------------------------------------
    # Cost calculation helpers
    # ---------------------------------------------------------------------------

    def self.compute_total_cost(assignment, sku_ids, sku_quantities)
      shop_subtotals = Hash.new(0.0)
      assignment.each_with_index do |offer, i|
        shop_subtotals[offer.shop_id] += offer.price * sku_quantities[sku_ids[i]]
      end
      shop_subtotals.sum do |_, sub|
        sub < Constants::MIN_SHIPPING_THRESHOLD ? sub + Constants::SHIPPING_COST : sub
      end
    end

    def self.filter_candidates(sku_offers_map)
      shop_sku_count = Hash.new(0)
      sku_offers_map.each_value do |offers|
        seen_shops = {}
        offers.each do |o|
          next if seen_shops[o.shop_id] || o.price >= Constants::MIN_SHIPPING_THRESHOLD

          shop_sku_count[o.shop_id] += 1
          seen_shops[o.shop_id] = true
        end
      end

      sku_offers_map.transform_values do |offers|
        min_price = offers.first.price
        filtered = offers.select do |o|
          count = shop_sku_count[o.shop_id] || 0
          cutoff = count <= 1 ? min_price : min_price + (count * Constants::SHIPPING_COST)
          o.price <= cutoff
        end
        filtered.empty? ? [offers.first] : filtered
      end
    end

    def self.run(sku_ids, sku_offers_map, sku_quantities, algorithm: :dp)
      filtered = filter_candidates(sku_offers_map)

      puts 'Candidates after price filter:'
      filtered.each do |sku_id, offers|
        puts "  SKU #{sku_id}: #{offers.length} candidate(s) (€#{'%.2f' % offers.first.price}–€#{'%.2f' % offers.last.price})"
      end
      puts

      algo_name = algorithm == :bnb ? 'branch-and-bound' : 'subset DP'
      puts "Optimising #{sku_ids.length} SKU(s) with #{algo_name}..."
      puts

      if algorithm == :bnb
        branch_and_bound(sku_ids, filtered, sku_quantities)
      else
        assignment_map = subset_dp(sku_ids, filtered, sku_quantities)
        sku_ids.map { |id| assignment_map[id] }
      end
    end
  end
end
