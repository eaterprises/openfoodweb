require 'open_food_network/enterprise_injection_data'

class EnterprisesController < BaseController
  layout "darkswarm"
  helper Spree::ProductsHelper
  include OrderCyclesHelper

  # These prepended filters are in the reverse order of execution
  prepend_before_filter :set_order_cycles, :require_distributor_chosen, :reset_order, only: :shop

  before_filter :clean_permalink, only: :check_permalink
  before_filter :enable_embedded_shopfront

  respond_to :js, only: :permalink_checker

  def shop
    return redirect_to main_app.cart_path unless enough_stock?
    set_noindex_meta_tag

    enterprises = current_distributor
      .plus_relatives_and_oc_producers(shop_order_cycles)
      .activated
      .includes(address: :state)
      .all

    enterprises = inject_json_ams('enterprises', enterprises)

    render locals: { enterprises: enterprises }
  end

  def relatives
    set_enterprise

    respond_to do |format|
      format.json do
        enterprises = @enterprise.andand.relatives.andand.activated
        render(json: enterprises,
               each_serializer: Api::EnterpriseSerializer,
               data: OpenFoodNetwork::EnterpriseInjectionData.new)
      end
    end
  end

  def check_permalink
    render text: params[:permalink], status: 409 and return if Enterprise.find_by_permalink params[:permalink]

    begin
      Rails.application.routes.recognize_path( "/#{ params[:permalink].to_s }" )
      render text: params[:permalink], status: 409
    rescue ActionController::RoutingError
      render text: params[:permalink], status: 200
    end
  end

  private

  def set_enterprise
    @enterprise = Enterprise.find_by_id(params[:id])
  end

  def clean_permalink
    params[:permalink] = params[:permalink].parameterize
  end

  def enough_stock?
    current_order(true).insufficient_stock_lines.blank?
  end

  def reset_order
    distributor = Enterprise.is_distributor.find_by_permalink(params[:id]) || Enterprise.is_distributor.find(params[:id])
    order = current_order(true)

    reset_distributor(order, distributor)

    reset_user_and_customer(order) if try_spree_current_user

    reset_order_cycle(order, distributor)

    order.save!
  end

  def reset_distributor(order, distributor)
    if order.distributor && order.distributor != distributor
      order.empty!
      order.set_order_cycle! nil
    end
    order.distributor = distributor
  end

  def reset_user_and_customer(order)
    order.associate_user!(spree_current_user) if order.user.blank? || order.email.blank?
    order.__send__(:associate_customer) if order.customer.nil? # Only associates existing customers
  end

  def reset_order_cycle(order, distributor)
    order_cycle_options = OrderCycle.active.with_distributor(distributor)
    order.order_cycle = order_cycle_options.first if order_cycle_options.count == 1
  end

  def shop_order_cycles
    if current_order_cycle
      [current_order_cycle]
    else
      OrderCycle.not_closed.with_distributor(current_distributor)
    end
  end

  def set_noindex_meta_tag
    @noindex_meta_tag = true unless current_distributor.visible?
  end

  def inject_json_ams(name, object)
    options = {
      each_serializer: Api::EnterpriseSerializer,
      data: OpenFoodNetwork::EnterpriseInjectionData.new
    }
    serializer_instance = ActiveModel::ArraySerializer.new(object, options)

    { name: name, json: serializer_instance.to_json }
  end
end
