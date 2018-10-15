require 'spec_helper'

feature "Order Management", js: true do
  include AuthenticationWorkflow

  describe "viewing a completed order" do
    let!(:distributor) { create(:distributor_enterprise) }
    let!(:customer) { create(:customer, user: user, enterprise: distributor) }
    let!(:order_cycle) { create(:simple_order_cycle, distributors: [distributor]) }

    let!(:bill_address) { create(:address) }
    let!(:ship_address) { create(:address) }
    let!(:shipping_method) { create(:free_shipping_method, distributors: [distributor]) }

    let!(:order) do
      create(:order_with_credit_payment,
        customer: customer,
        user: user,
        distributor: distributor,
        order_cycle: order_cycle
      )
    end

    before do
      # For some reason, both bill_address and ship_address are not set
      # automatically.
      #
      # Also, assigning the shipping_method to a ShippingMethod instance results
      # in a SystemStackError.
      order.update_attributes!(
        bill_address: bill_address,
        ship_address: ship_address,
        shipping_method_id: shipping_method.id
      )
    end

    context "when checking out as an anonymous guest" do
      let(:user) { nil }

      it "allows the user to see the details" do
        # Cannot load the page without token
        visit spree.order_path(order)
        expect(page).to_not be_confirmed_order_page

        # Can load the page with token
        visit spree.order_path(order, token: order.token)
        expect(page).to be_confirmed_order_page

        # Can load the page even without the token, after loading the page with
        # token.
        visit spree.order_path(order)
        expect(page).to be_confirmed_order_page
      end
    end

    context "when logged in as the customer" do
      let(:user) { create(:user) }

      before do
        login_as user
      end

      it "allows the user to see order details" do
        visit spree.order_path(order)
        expect(page).to be_confirmed_order_page
      end
    end

    context "when not logged in" do
      let(:user) { create(:user) }

      it "allows the user to see order details after login" do
        # Cannot load the page without signing in
        visit spree.order_path(order)
        expect(page).to_not be_confirmed_order_page

        # Can load the page after signing in
        fill_in_and_submit_login_form user
        expect(page).to be_confirmed_order_page
      end
    end
  end

  describe "editing a completed order" do
    let(:address) { create(:address) }
    let(:user) { create(:user, bill_address: address, ship_address: address) }
    let(:distributor) { create(:distributor_enterprise, with_payment_and_shipping: true, charges_sales_tax: true) }
    let(:order_cycle) { create(:order_cycle) }
    let(:shipping_method) { distributor.shipping_methods.first }
    let(:order) { create(:completed_order_with_totals, order_cycle: order_cycle, distributor: distributor, user: user, bill_address: address, ship_address: address) }
    let!(:item1) { order.reload.line_items.first }
    let!(:item2) { create(:line_item, order: order) }
    let!(:item3) { create(:line_item, order: order) }

    before do
      shipping_method.calculator.update_attributes(preferred_amount: 5.0)
      order.shipments = [create(:shipment_with, :shipping_method, shipping_method: shipping_method)]
      order.reload.save
      quick_login_as user
    end

    it 'shows the name of the shipping method' do
      visit spree.order_path(order)
      expect(find('#order')).to have_content(shipping_method.name)
    end

    context "when the distributor doesn't allow changes to be made to orders" do
      before do
        order.distributor.update_attributes(allow_order_changes: false)
      end

      it "doesn't show form elements for editing the order" do
        visit spree.order_path(order)
        expect(find("tr.variant-#{item1.variant.id}")).to have_content item1.product.name
        expect(find("tr.variant-#{item2.variant.id}")).to have_content item2.product.name
        expect(find("tr.variant-#{item3.variant.id}")).to have_content item3.product.name
        expect(page).to have_no_button I18n.t(:save_changes)
      end
    end

    context "when the distributor allows changes to be made to orders" do
      before do
        Spree::Config[:mails_from] = "spree@example.com"
      end
      before do
        order.distributor.update_attributes(allow_order_changes: true)
      end

      it "allows quantity to be changed, items to be removed and the order to be cancelled" do
        visit spree.order_path(order)

        expect(page).to have_button I18n.t(:order_saved), disabled: true
        expect(page).to have_no_button I18n.t(:save_changes)

        # Changing the quantity of an item
        within "tr.variant-#{item1.variant.id}" do
          expect(page).to have_content item1.product.name
          expect(page).to have_field 'order_line_items_attributes_0_quantity'
          fill_in 'order_line_items_attributes_0_quantity', with: 2
        end

        expect(page).to have_button I18n.t(:save_changes)

        expect(find("tr.variant-#{item2.variant.id}")).to have_content item2.product.name
        expect(find("tr.variant-#{item3.variant.id}")).to have_content item3.product.name
        expect(find("tr.order-adjustment")).to have_content "Shipping"
        expect(find("tr.order-adjustment")).to have_content "$5.00"

        click_button I18n.t(:save_changes)

        expect(find(".order-total.grand-total")).to have_content "$45.00"
        expect(item1.reload.quantity).to eq 2

        # Deleting an item
        within "tr.variant-#{item2.variant.id}" do
          click_link "delete_line_item_#{item2.id}"
        end

        expect(find(".order-total.grand-total")).to have_content "$35.00"
        expect(Spree::LineItem.find_by_id(item2.id)).to be nil

        # Cancelling the order
        click_link(I18n.t(:cancel_order))
        expect(page).to have_content I18n.t(:orders_show_cancelled)
        expect(order.reload).to be_canceled
      end
    end
  end

  def be_confirmed_order_page
    have_content /Order #\w+ Confirmed NOT PAID/
  end
end
