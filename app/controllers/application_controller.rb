class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :load_data_for_menu
  before_filter :load_data_for_sidebar
  before_filter :require_certified_hostname

  include EnterprisesHelper

  def after_sign_in_path_for(resource)
    if request.referer and referer_path = URI(request.referer).path
      [main_app.shop_checkout_path].include?(referer_path) ? referer_path : root_path
    else
      root_path
    end
  end

  private
  def load_data_for_menu
    @cms_site = Cms::Site.where(:identifier => 'open-food-network').first
  end

  # This is getting sloppy, since @all_distributors is also used for order cycle selection,
  # which is not in the sidebar. I don't like having an application controller method that's
  # coupled to several parts of the code. We might be able to solve this using cells:
  # https://github.com/apotonick/cells
  def load_data_for_sidebar
    sidebar_distributors_limit = false
    sidebar_suppliers_limit = false

    @order_cycles = OrderCycle.active

    @sidebar_suppliers = Enterprise.is_primary_producer.with_supplied_active_products_on_hand.limit(sidebar_suppliers_limit)
    @total_suppliers = Enterprise.is_primary_producer.distinct_count

    @sidebar_distributors = Enterprise.active_distributors.by_name.limit(sidebar_distributors_limit)
    @all_distributors = Enterprise.active_distributors
    @total_distributors = Enterprise.is_distributor.distinct_count
  end

  def require_distributor_chosen
    unless current_distributor
      redirect_to spree.root_path
      false
    end
  end

  def require_order_cycle
    unless current_order_cycle
      redirect_to main_app.shop_path
    end
  end

  def check_order_cycle_expiry
    if current_order_cycle.andand.closed?
      session[:expired_order_cycle_id] = current_order_cycle.id
      current_order.empty!
      current_order.set_order_cycle! nil
      redirect_to spree.order_cycle_expired_orders_path
    end
  end

  # There are several domains that point to the production server, but only one
  # (vic.openfoodnetwork.org) that has the SSL certificate. Redirect all requests to this
  # domain to avoid showing customers a scary invalid certificate error.
  def require_certified_hostname
    certified_host = "vic.openfoodnetwork.org"

    if OpenFoodNetwork::Config.country_code == 'au' && Rails.env.production? && request.host != certified_host
      redirect_to "http://#{certified_host}#{request.fullpath}"
    end
  end


  # All render calls within the block will be performed with the specified format
  # Useful for rendering html within a JSON response, particularly if the specified
  # template or partial then goes on to render further partials without specifying
  # their format.
  def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    block.call
    self.formats = old_formats
    nil
  end

end
