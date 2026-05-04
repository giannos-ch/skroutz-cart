module SkroutzCart
  class CartItem
    attr_reader :sku_id, :quantity

    def initialize(sku_id, quantity)
      @sku_id = sku_id
      @quantity = quantity
    end
  end
end
