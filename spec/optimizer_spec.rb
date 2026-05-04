require 'spec_helper'
require 'skroutz_cart/optimizer'
require 'skroutz_cart/models/shop_offer'

RSpec.describe SkroutzCart::Optimizer do
  # Helper to build a ShopOffer quickly
  def offer(shop_id:, price:, product_id: nil, product_name: 'Product')
    SkroutzCart::ShopOffer.new(
      shop_id: shop_id,
      shop_name: "Shop #{shop_id}",
      price: price,
      product_name: product_name,
      product_id: product_id || shop_id * 100
    )
  end

  describe '.compute_total_cost' do
    it 'adds shipping for shops below the threshold' do
      o1 = offer(shop_id: 1, price: 5.0)
      o2 = offer(shop_id: 2, price: 6.0)
      assignment = [o1, o2]
      sku_ids = %w[sku1 sku2]
      quantities = { 'sku1' => 1, 'sku2' => 1 }

      # shop1: 5.0 < 15 → +2.5 shipping; shop2: 6.0 < 15 → +2.5 shipping
      cost = described_class.compute_total_cost(assignment, sku_ids, quantities)
      expect(cost).to be_within(0.001).of(16.0)
    end

    it 'does not add shipping when subtotal meets threshold' do
      o1 = offer(shop_id: 1, price: 10.0)
      o2 = offer(shop_id: 1, price: 7.0)
      assignment = [o1, o2]
      sku_ids = %w[sku1 sku2]
      quantities = { 'sku1' => 1, 'sku2' => 1 }

      # shop1 subtotal: 17.0 ≥ 15 → free shipping
      cost = described_class.compute_total_cost(assignment, sku_ids, quantities)
      expect(cost).to be_within(0.001).of(17.0)
    end

    it 'respects item quantity when calculating subtotals' do
      o1 = offer(shop_id: 1, price: 5.0)
      assignment = [o1]
      sku_ids = ['sku1']
      quantities = { 'sku1' => 4 }

      # subtotal 20.0 ≥ 15 → free shipping
      cost = described_class.compute_total_cost(assignment, sku_ids, quantities)
      expect(cost).to be_within(0.001).of(20.0)
    end
  end

  describe '.subset_dp' do
    context 'with a single SKU and one shop' do
      it 'returns the single offer' do
        o = offer(shop_id: 1, price: 8.0)
        sku_offers = { 'sku1' => [o] }
        quantities = { 'sku1' => 1 }

        result = described_class.subset_dp(['sku1'], sku_offers, quantities)
        expect(result['sku1']).to eq(o)
      end
    end

    context 'with two SKUs where buying from one shop is cheaper' do
      it 'consolidates into the single shop to avoid two shipping fees' do
        # Shop 1 sells both items cheaply enough to avoid double shipping
        s1_sku1 = offer(shop_id: 1, price: 8.0, product_name: 'P1')
        s2_sku1 = offer(shop_id: 2, price: 6.0, product_name: 'P1')
        s1_sku2 = offer(shop_id: 1, price: 8.0, product_name: 'P2')
        s2_sku2 = offer(shop_id: 2, price: 6.0, product_name: 'P2')

        # Shop 2 each item: 6+6=12 < 15 → 12+2.5=14.5 total
        # Shop 1 each item: 8+8=16 ≥ 15 → 16.0 total
        # Cheapest per-shop split: sku1 from shop2(6+2.5) + sku2 from shop2 already counted
        # All from shop2: 14.5; all from shop1: 16.0; split: same shop2 wins.
        sku_offers = { 'sku1' => [s2_sku1, s1_sku1], 'sku2' => [s2_sku2, s1_sku2] }
        quantities = { 'sku1' => 1, 'sku2' => 1 }

        result = described_class.subset_dp(%w[sku1 sku2], sku_offers, quantities)
        expect(result['sku1'].shop_id).to eq(2)
        expect(result['sku2'].shop_id).to eq(2)
      end

      it 'splits across shops when overall cost is lower' do
        # sku1: only in shop1 at 4.0; sku2: only in shop2 at 4.0
        # Each shop sub 4.0 < 15 → two shipping fees: 4+2.5 + 4+2.5 = 13.0
        # There is no consolidation option, so split is forced
        s1_sku1 = offer(shop_id: 1, price: 4.0)
        s2_sku2 = offer(shop_id: 2, price: 4.0)
        sku_offers = { 'sku1' => [s1_sku1], 'sku2' => [s2_sku2] }
        quantities = { 'sku1' => 1, 'sku2' => 1 }

        result = described_class.subset_dp(%w[sku1 sku2], sku_offers, quantities)
        expect(result['sku1'].shop_id).to eq(1)
        expect(result['sku2'].shop_id).to eq(2)
      end
    end

    context 'with an empty sku list' do
      it 'returns an empty hash' do
        result = described_class.subset_dp([], {}, {})
        expect(result).to eq({})
      end
    end
  end

  describe '.branch_and_bound' do
    it 'returns the optimal assignment matching subset_dp' do
      s1_a = offer(shop_id: 1, price: 8.0, product_name: 'A')
      s2_a = offer(shop_id: 2, price: 6.5, product_name: 'A')
      s1_b = offer(shop_id: 1, price: 7.0, product_name: 'B')
      s2_b = offer(shop_id: 2, price: 7.5, product_name: 'B')

      sku_offers = { 'sku1' => [s2_a, s1_a], 'sku2' => [s1_b, s2_b] }
      quantities = { 'sku1' => 1, 'sku2' => 1 }
      sku_ids    = %w[sku1 sku2]

      bnb_result = described_class.branch_and_bound(sku_ids, sku_offers, quantities)
      dp_result  = described_class.subset_dp(sku_ids, sku_offers, quantities)

      bnb_cost = described_class.compute_total_cost(bnb_result, sku_ids, quantities)
      dp_cost  = described_class.compute_total_cost(sku_ids.map { |id| dp_result[id] }, sku_ids, quantities)

      expect(bnb_cost).to be_within(0.001).of(dp_cost)
    end
  end

  describe '.filter_candidates' do
    it 'keeps only the cheapest offer when a shop covers one SKU' do
      cheap = offer(shop_id: 1, price: 5.0)
      pricey = offer(shop_id: 2, price: 20.0)
      sku_offers = { 'sku1' => [cheap, pricey] }

      result = described_class.filter_candidates(sku_offers)
      expect(result['sku1']).to eq([cheap])
    end

    it 'always returns at least one offer per SKU' do
      only = offer(shop_id: 1, price: 5.0)
      sku_offers = { 'sku1' => [only] }

      result = described_class.filter_candidates(sku_offers)
      expect(result['sku1']).not_to be_empty
    end
  end
end
