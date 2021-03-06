class Order < ApplicationRecord
  before_create :set_uuid

  def set_uuid
    self.uuid = SecureRandom.uuid
  end
  

  def json_object
    ids_products = OrderProduct.where(order_id: self.id)
    products = Product.where(id: ids_products).map {|x| x.json_object}

    return {
      uuid: uuid,
      price: price,
      restaurant: restaurant,
      products: products,
      created_at: created_at.to_i
    }
  end
  
end
