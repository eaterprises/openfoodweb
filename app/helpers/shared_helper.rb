module SharedHelper
  def distributor_link_class(distributor)
    cart = current_order(true)
    @active_distributors ||= Enterprise.distributors_with_active_order_cycles

    klass = "shop-distributor"
    klass += " empties-cart" unless cart.line_items.empty? || cart.distributor == distributor
    klass += @active_distributors.include?(distributor) ? ' active' : ' inactive'
    klass
  end

  # all suppliers of current distributor's products
  def current_producers
    if current_distributor && current_order_cycle
      variants = current_order_cycle.variants_distributed_by(current_distributor)
      Enterprise.supplying_variant_in(variants)
    else
      []
    end
  end
  
  def enterprise_user?
    spree_current_user.andand.enterprises.count > 0
  end
end
