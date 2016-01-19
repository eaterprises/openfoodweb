require 'spec_helper'

describe CheckoutHelper do
  it "generates html for validated inputs" do
    helper.should_receive(:render).with(
      "shared/validated_input",
      name: "test",
      path: "foo",
      attributes: {:required=>true, :type=>:email, :name=>"foo", :id=>"foo", "ng-model"=>"foo", "ng-class"=>"{error: !fieldValid('foo')}"}
    )

    helper.validated_input("test", "foo", type: :email)
  end

  describe "displaying the tax total for an order" do
    let(:order) { double(:order, total_tax: 123.45, currency: 'AUD') }

    it "retrieves the total tax on the order" do
      helper.display_checkout_tax_total(order).should == Spree::Money.new(123.45, currency: 'AUD')
    end
  end
end
