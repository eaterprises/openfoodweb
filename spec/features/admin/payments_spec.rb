# frozen_string_literal: true

require 'spec_helper'

feature '
    As an admin
    I want to manage payments
' do
  include AuthenticationHelper

  let(:order) { create(:completed_order_with_fees) }

  it "renders the new payment page" do
    login_as_admin_and_visit spree.new_admin_order_payment_path order

    expect(page).to have_content "New Payment"
  end

  it 'displays the order balance as the default payment amount' do
    login_as_admin_and_visit spree.new_admin_order_payment_path order

    expect(page).to have_field(:payment_amount, with: order.outstanding_balance)
  end

  context "with sensitive payment fee" do
    before do
      payment_method = create(:payment_method, distributors: [order.distributor])

      # This calculator doesn't handle a `nil` order well.
      # That has been useful in finding bugs. ;-)
      payment_method.calculator = Calculator::FlatPercentItemTotal.new
      payment_method.save!
    end

    it "renders the new payment page" do
      login_as_admin_and_visit spree.new_admin_order_payment_path order

      expect(page).to have_content "New Payment"
    end
  end
end
