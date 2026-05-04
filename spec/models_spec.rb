require 'spec_helper'
require 'skroutz_cart/models/cart_item'
require 'skroutz_cart/models/shop_offer'

RSpec.describe SkroutzCart::CartItem do
  describe '#initialize' do
    it 'stores sku_id and quantity' do
      item = described_class.new(12_345, 3)
      expect(item.sku_id).to eq(12_345)
      expect(item.quantity).to eq(3)
    end
  end
end

RSpec.describe SkroutzCart::ShopOffer do
  let(:data) do
    { shop_id: 42, shop_name: 'Best Shop', price: 9.99,
      product_name: 'Widget Pro', product_id: 7 }
  end

  describe '#initialize' do
    it 'stores all attributes from hash' do
      offer = described_class.new(data)
      expect(offer.shop_id).to eq(42)
      expect(offer.shop_name).to eq('Best Shop')
      expect(offer.price).to eq(9.99)
      expect(offer.product_name).to eq('Widget Pro')
      expect(offer.product_id).to eq(7)
    end
  end
end
