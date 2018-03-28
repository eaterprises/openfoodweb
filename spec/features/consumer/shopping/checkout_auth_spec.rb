require 'spec_helper'

feature "As a consumer I want to check out my cart", js: true do
  include AuthenticationWorkflow
  include WebHelper
  include ShopWorkflow
  include CheckoutWorkflow
  include UIComponentHelper

  let(:distributor) { create(:distributor_enterprise, with_payment_and_shipping: true) }
  let(:supplier) { create(:supplier_enterprise) }
  let!(:order_cycle) { create(:simple_order_cycle, distributors: [distributor], coordinator: create(:distributor_enterprise), variants: [product.variants.first]) }
  let(:product) { create(:simple_product, supplier: supplier) }
  let(:order) { create(:order, order_cycle: order_cycle, distributor: distributor) }
  let(:address) { create(:address, firstname: "Foo", lastname: "Bar") }
  let(:user) { create(:user, bill_address: address, ship_address: address) }
  after { Warden.test_reset! }

  before do
    set_order order
    add_product_to_cart order, product
  end

  it "does not not render the login form when logged in" do
    quick_login_as user
    visit checkout_path
    within "section[role='main']" do
      expect(page).not_to have_content "Login"
      expect(page).to have_checkout_details
    end
  end

  it "renders the login buttons when logged out" do
    visit checkout_path
    within "section[role='main']" do
      expect(page).to have_content "Login"
      click_button "Login"
    end
    expect(page).to have_login_modal
  end

  it "populates user details once logged in" do
    visit checkout_path
    within("section[role='main']") { click_button "Login" }
    expect(page).to have_login_modal
    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    within(".login-modal") { click_button 'Login' }
    toggle_details

    expect(page).to have_field 'First Name', with: 'Foo'
    expect(page).to have_field 'Last Name', with: 'Bar'
  end

  it "allows user to checkout as guest" do
    visit checkout_path
    checkout_as_guest
    expect(page).to have_checkout_details
  end
end
