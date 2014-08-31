class CheckoutController < Spree::CheckoutController
  layout 'darkswarm'

  prepend_before_filter :check_order_cycle_expiry
  prepend_before_filter :require_order_cycle
  prepend_before_filter :require_distributor_chosen

  skip_before_filter :check_registration
  skip_before_filter :redirect_to_paypal_express_form_if_needed

  include OrderCyclesHelper
  include EnterprisesHelper
   
  def edit
    # Because this controller doesn't inherit from our BaseController
    # We need to duplicate the code here
    @active_distributors ||= Enterprise.distributors_with_active_order_cycles
  end

  def update
    if @order.update_attributes(object_params)
      fire_event('spree.checkout.update')
      while @order.state != "complete"
        if @order.state == "payment"
          return if redirect_to_paypal_express_form_if_needed
        end

        if @order.next
          state_callback(:after)
        else
          if @order.errors.present?
            flash[:error] = @order.errors.full_messages.to_sentence
          else
            flash[:error] = t(:payment_processing_failed)
          end
          update_failed
          return
        end
      end
      if @order.state == "complete" ||  @order.completed?
        flash[:success] = t(:order_processed_successfully)
          respond_to do |format|
            format.html do
              respond_with(@order, :location => order_path(@order))
            end
            format.js do
              render json: {path: order_path(@order)}, status: 200
            end
          end
      else
        update_failed
      end
    else
      update_failed
    end
  end


  private
  
  # Copied and modified from spree. Remove check for order state, since the state machine is
  # progressed all the way in one go with the one page checkout.
  def object_params
    # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
    if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
      params[:order][:payments_attributes].first[:source_attributes] = source_params
    end
    if (params[:order][:payments_attributes])
      params[:order][:payments_attributes].first[:amount] = @order.total
    end
    params[:order]
  end


  def update_failed
    clear_ship_address
    respond_to do |format|
      format.html do
        render :edit
      end
      format.js do
        render json: {errors: @order.errors, flash: flash.to_hash}.to_json, status: 400
      end
    end
  end

  # When we have a pickup Shipping Method, we clone the distributor address into ship_address before_save
  # We don't want this data in the form, so we clear it out
  def clear_ship_address
    unless current_order.shipping_method.andand.require_ship_address
      current_order.ship_address = Spree::Address.default
    end
  end

  def skip_state_validation?
    true
  end
  
  def load_order
    @order = current_order
    redirect_to main_app.shop_path and return unless @order and @order.checkout_allowed?
    raise_insufficient_quantity and return if @order.insufficient_stock_lines.present?
    redirect_to main_app.shop_path and return if @order.completed?
    before_address
    state_callback(:before)
  end

  def before_address
    associate_user
    last_used_bill_address, last_used_ship_address = find_last_used_addresses(@order.email)
    preferred_bill_address, preferred_ship_address = spree_current_user.bill_address, spree_current_user.ship_address if spree_current_user.respond_to?(:bill_address) && spree_current_user.respond_to?(:ship_address)
    @order.bill_address ||= preferred_bill_address || last_used_bill_address || Spree::Address.default
    @order.ship_address ||= preferred_ship_address || last_used_ship_address || Spree::Address.default 
  end

  # Overriding Spree's methods
  def raise_insufficient_quantity
    flash[:error] = t(:spree_inventory_error_flash_for_insufficient_quantity)
    redirect_to main_app.shop_path
  end

  # Overriding from github.com/spree/spree_paypal_express
  def redirect_to_paypal_express_form_if_needed
    return unless params[:order][:payments_attributes]

    payment_method = Spree::PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])
    return unless payment_method.kind_of?(Spree::BillingIntegration::PaypalExpress) || payment_method.kind_of?(Spree::BillingIntegration::PaypalExpressUk)

    update_params = object_params.dup
    update_params.delete(:payments_attributes)
    if @order.update_attributes(update_params)
      fire_event('spree.checkout.update')
      render :edit and return unless apply_coupon_code
    end

    load_order
    if not @order.errors.empty?
       render :edit and return
    end

    render json: {path: main_app.paypal_payment_url(@order, :payment_method_id => payment_method.id)}, status: 200
    true
  end
  
  # Overriding to customize the cancel url
  def order_opts_with_new_cancel_return_url(order, payment_method_id, stage)
    opts = order_opts_without_new_cancel_return_url(order, payment_method_id, stage)
    opts[:cancel_return_url] = main_app.checkout_url
    opts
  end
  alias_method_chain :order_opts, :new_cancel_return_url
end
