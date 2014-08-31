require 'spec_helper'

describe Spree::OrdersController do
  let(:distributor) { double(:distributor) }
  let(:order) { create(:order) }
  let(:order_cycle) { create(:simple_order_cycle) }

  it "redirects home when no distributor is selected" do
    spree_get :edit
    response.should redirect_to root_path
  end

  it "redirects to shop when order is empty" do
    controller.stub(:current_distributor).and_return(distributor)
    controller.stub(:current_order_cycle).and_return(order_cycle)
    controller.stub(:current_order).and_return order
    order.stub_chain(:line_items, :empty?).and_return true
    session[:access_token] = order.token
    spree_get :edit
    response.should redirect_to shop_path
  end

  it "redirects to the shop when no order cycle is selected" do
    controller.stub(:current_distributor).and_return(distributor)
    spree_get :edit
    response.should redirect_to shop_path
  end

  it "selects distributors" do
    d = create(:distributor_enterprise)
    p = create(:product, :distributors => [d])

    spree_get :select_distributor, :id => d.id
    response.should be_redirect

    order = subject.current_order(false)
    order.distributor.should == d
  end

  it "deselects distributors" do
    d = create(:distributor_enterprise)
    p = create(:product, :distributors => [d])
    
    order = subject.current_order(true)
    order.distributor = d
    order.save!

    spree_get :deselect_distributor
    response.should be_redirect

    order.reload
    order.distributor.should be_nil
  end

  context "adding a group buy product to the cart" do
    it "sets a variant attribute for the max quantity" do
      distributor_product = create(:distributor_enterprise)
      p = create(:product, :distributors => [distributor_product], :group_buy => true)

      order = subject.current_order(true)
      order.stub(:distributor) { distributor_product }
      order.should_receive(:set_variant_attributes).with(p.master, {'max_quantity' => '3'})
      controller.stub(:current_order).and_return(order)

      expect do
        spree_post :populate, :variants => {p.master.id => 1}, :variant_attributes => {p.master.id => {:max_quantity => 3}}
      end.to change(Spree::LineItem, :count).by(1)
    end
  end

  context "removing line items from cart" do
    describe "when I pass params that includes a line item no longer in our cart" do
      it "should silently ignore the missing line item" do
        order = subject.current_order(true)
        li = order.add_variant(create(:simple_product, on_hand: 110).master)
        spree_get :update, order: { line_items_attributes: {
          "0" => {quantity: "0", id: "9999"},
          "1" => {quantity: "99", id: li.id}
        }}
        response.status.should == 302
        li.reload.quantity.should == 99
      end
    end

    it "filters line items that are missing from params" do
      order = subject.current_order(true)
      li = order.add_variant(create(:simple_product).master)

      attrs = {
        "0" => {quantity: "0", id: "9999"},
        "1" => {quantity: "99", id: li.id}
      }

      controller.remove_missing_line_items(attrs).should == {
        "1" => {quantity: "99", id: li.id}
      }
    end
  end


  private

  def num_items_in_cart
    Spree::Order.last.andand.line_items.andand.count || 0
  end
end
