require 'spec_helper'

describe CheckoutController, type: :controller do
  let(:distributor) { double(:distributor) }
  let(:order_cycle) { create(:simple_order_cycle) }
  let(:order) { create(:order) }
  let(:reset_order_service) { double(ResetOrderService) }

  before do
    allow(order).to receive(:checkout_allowed?).and_return true
    allow(controller).to receive(:check_authorization).and_return true
  end

  it "redirects home when no distributor is selected" do
    get :edit
    expect(response).to redirect_to root_path
  end

  it "redirects to the shop when no order cycle is selected" do
    allow(controller).to receive(:current_distributor).and_return(distributor)
    get :edit
    expect(response).to redirect_to shop_path
  end

  it "redirects home with message if hub is not ready for checkout" do
    allow(distributor).to receive(:ready_for_checkout?) { false }
    allow(order).to receive_messages(distributor: distributor, order_cycle: order_cycle)
    allow(controller).to receive(:current_order).and_return(order)

    expect(order).to receive(:empty!)
    expect(order).to receive(:set_distribution!).with(nil, nil)

    get :edit

    expect(response).to redirect_to root_url
    expect(flash[:info]).to eq("The hub you have selected is temporarily closed for orders. Please try again later.")
  end

  describe "redirection to the cart" do
    let(:order_cycle_distributed_variants) { double(:order_cycle_distributed_variants) }

    before do
      allow(controller).to receive(:current_order).and_return(order)
      allow(order).to receive(:distributor).and_return(distributor)
      order.order_cycle = order_cycle

      allow(OrderCycleDistributedVariants).to receive(:new).with(order_cycle, distributor).and_return(order_cycle_distributed_variants)      
    end

    it "redirects when some items are out of stock" do
      allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return false

      get :edit
      expect(response).to redirect_to cart_path
    end

    it "redirects when some items are not available" do
      allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return true
      expect(order_cycle_distributed_variants).to receive(:distributes_order_variants?).with(order).and_return(false)

      get :edit
      expect(response).to redirect_to cart_path
    end

    it "does not redirect when items are available and in stock" do
      allow(order).to receive_message_chain(:insufficient_stock_lines, :empty?).and_return true
      expect(order_cycle_distributed_variants).to receive(:distributes_order_variants?).with(order).and_return(true)

      get :edit
      expect(response).to be_success
    end
  end

  describe "building the order" do
    before do
      allow(controller).to receive(:current_distributor).and_return(distributor)
      allow(controller).to receive(:current_order_cycle).and_return(order_cycle)
      allow(controller).to receive(:current_order).and_return(order)
    end

    it "does not clone the ship address from distributor when shipping method requires address" do
      get :edit
      expect(assigns[:order].ship_address.address1).to be_nil
    end

    it "clears the ship address when re-rendering edit" do
      expect(controller).to receive(:clear_ship_address).and_return true
      allow(order).to receive(:update_attributes).and_return false
      spree_post :update, format: :json, order: {}
    end

    it "clears the ship address when the order state cannot be advanced" do
      expect(controller).to receive(:clear_ship_address).and_return true
      allow(order).to receive(:update_attributes).and_return true
      allow(order).to receive(:next).and_return false
      spree_post :update, format: :json, order: {}
    end

    it "only clears the ship address with a pickup shipping method" do
      allow(order).to receive_message_chain(:shipping_method, :andand, :require_ship_address).and_return false
      expect(order).to receive(:ship_address=)
      controller.send(:clear_ship_address)
    end

    context "#update with shipping_method_id" do
      let(:test_shipping_method_id) { "111" }

      before do
        # stub order and resetorderservice
        allow(ResetOrderService).to receive(:new).with(controller, order) { reset_order_service }
        allow(reset_order_service).to receive(:call)
        allow(order).to receive(:update_attributes).and_return true
        allow(controller).to receive(:current_order).and_return order

        # make order workflow pass through delivery
        allow(order).to receive(:next).twice do
          if order.state == 'cart'
            order.update_column :state, 'delivery'
          else
            order.update_column :state, 'complete'
          end
        end
      end

      it "does not fail to update" do
        expect(controller).to_not receive(:clear_ship_address)
        spree_post :update, order: {shipping_method_id: test_shipping_method_id}
      end

      it "does not send shipping_method_id to the order model as an attribute" do
        expect(order).to receive(:update_attributes).with({})
        spree_post :update, order: {shipping_method_id: test_shipping_method_id}
      end

      it "selects the shipping_method in the order" do
        expect(order).to receive(:select_shipping_method).with(test_shipping_method_id)
        spree_post :update, order: {shipping_method_id: test_shipping_method_id}
      end
    end

    context 'when completing the order' do
      before do
        order.state = 'complete'
        allow(order).to receive(:update_attributes).and_return(true)
        allow(order).to receive(:next).and_return(true)
        allow(order).to receive(:set_distributor!).and_return(true)
      end

      it "sets the new order's token to the same as the old order" do
        order = controller.current_order(true)
        spree_post :update, order: {}
        expect(controller.current_order.token).to eq order.token
      end

      it 'expires the current order' do
        allow(controller).to receive(:expire_current_order)
        put :update, order: {}
        expect(controller).to have_received(:expire_current_order)
      end

      it 'sets the access_token of the session' do
        put :update, order: {}
        expect(session[:access_token]).to eq(controller.current_order.token)
      end
    end
  end

  describe '#expire_current_order' do
    it 'empties the order_id of the session' do
      expect(session).to receive(:[]=).with(:order_id, nil)
      controller.expire_current_order
    end

    it 'resets the @current_order ivar' do
      controller.expire_current_order
      expect(controller.instance_variable_get(:@current_order)).to be_nil
    end
  end

  context "via xhr" do
    before do
      allow(controller).to receive(:current_distributor).and_return(distributor)

      allow(controller).to receive(:current_order_cycle).and_return(order_cycle)
      allow(controller).to receive(:current_order).and_return(order)
    end

    it "returns errors" do
      spree_post :update, format: :json, order: {}
      expect(response.status).to eq(400)
      expect(response.body).to eq({errors: assigns[:order].errors, flash: {}}.to_json)
    end

    it "returns flash" do
      allow(order).to receive(:update_attributes).and_return true
      allow(order).to receive(:next).and_return false
      spree_post :update, format: :json, order: {}
      expect(response.body).to eq({errors: assigns[:order].errors, flash: {error: "Payment could not be processed, please check the details you entered"}}.to_json)
    end

    it "returns order confirmation url on success" do
      allow(ResetOrderService).to receive(:new).with(controller, order) { reset_order_service }
      expect(reset_order_service).to receive(:call)

      allow(order).to receive(:update_attributes).and_return true
      allow(order).to receive(:state).and_return "complete"

      spree_post :update, format: :json, order: {}
      expect(response.status).to eq(200)
      expect(response.body).to eq({path: spree.order_path(order)}.to_json)
    end

    describe "stale object handling" do
      it "retries when a stale object error is encountered" do
        allow(ResetOrderService).to receive(:new).with(controller, order) { reset_order_service }
        expect(reset_order_service).to receive(:call)

        allow(order).to receive(:update_attributes).and_return true
        allow(controller).to receive(:state_callback)

        # The first time, raise a StaleObjectError. The second time, succeed.
        allow(order).to receive(:next).once.
          and_raise(ActiveRecord::StaleObjectError.new(Spree::Variant.new, 'update'))
        allow(order).to receive(:next).once do
          order.update_column :state, 'complete'
          true
        end

        spree_post :update, format: :json, order: {}
        expect(response.status).to eq(200)
      end

      it "tries a maximum of 3 times before giving up and returning an error" do
        allow(order).to receive(:update_attributes).and_return true
        allow(order).to receive(:next) { raise ActiveRecord::StaleObjectError.new(Spree::Variant.new, 'update') }

        spree_post :update, format: :json, order: {}
        expect(response.status).to eq(400)
      end
    end
  end

  describe "Paypal routing" do
    let(:payment_method) { create(:payment_method, type: "Spree::Gateway::PayPalExpress") }
    let(:restart_checkout) { instance_double(RestartCheckout, call: true) }

    before do
      allow(controller).to receive(:current_distributor) { distributor }
      allow(controller).to receive(:current_order_cycle) { order_cycle }
      allow(controller).to receive(:current_order) { order }

      allow(RestartCheckout).to receive(:new) { restart_checkout }
    end

    it "should check the payment method for Paypalness if we've selected one" do
      expect(Spree::PaymentMethod).to receive(:find).with(payment_method.id.to_s) { payment_method }
      allow(order).to receive(:update_attributes) { true }
      allow(order).to receive(:state) { "payment" }
      spree_post :update, order: {payments_attributes: [{payment_method_id: payment_method.id}]}
    end
  end

  describe "#update_failed" do
    let(:restart_checkout) { instance_double(RestartCheckout, call: true) }

    before do
      controller.instance_variable_set(:@order, order)
      allow(RestartCheckout).to receive(:new) { restart_checkout }
    end

    it "clears the shipping address and restarts the checkout" do
      expect(controller).to receive(:clear_ship_address)
      expect(restart_checkout).to receive(:call)
      expect(controller).to receive(:respond_to)

      controller.send(:update_failed)
    end
  end
end
