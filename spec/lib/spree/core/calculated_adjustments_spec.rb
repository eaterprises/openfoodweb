# frozen_string_literal: true

require 'spec_helper'

describe Spree::Core::CalculatedAdjustments do
  it "should add has_one :calculator relationship" do
    assert Spree::ShippingMethod.
      reflect_on_all_associations(:has_one).map(&:name).include?(:calculator)
  end
end
