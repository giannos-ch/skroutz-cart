module SkroutzCart
  class ShopOffer
    attr_reader :shop_id, :shop_name, :price, :product_name, :product_id, :free_shipping

    def initialize(data)
      @free_shipping = data[:free_shipping] || false
      @shop_id = data[:shop_id]
      @shop_name = data[:shop_name]
      @price = data[:price]
      @product_name = data[:product_name]
      @product_id = data[:product_id]
    end
  end
end
