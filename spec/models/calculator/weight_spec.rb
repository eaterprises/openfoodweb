require 'spec_helper'

describe Calculator::Weight do
  it_behaves_like "a model using the LocalizedNumber module", [:preferred_per_kg]

  it "computes shipping cost for an order by total weight" do
    variant1 = build(:variant, weight: 10)
    variant2 = build(:variant, weight: 20)
    variant3 = build(:variant, weight: nil)

    line_item1 = build(:line_item, variant: variant1, quantity: 1)
    line_item2 = build(:line_item, variant: variant2, quantity: 3)
    line_item3 = build(:line_item, variant: variant3, quantity: 5)

    order = double(:order, line_items: [line_item1, line_item2, line_item3])

    subject.set_preference(:per_kg, 10)
    expect(subject.compute(order)).to eq((10 * 1 + 20 * 3) * 10)
  end

  describe "line item with variant weight" do
    let(:variant) { build(:variant, weight: 10) }
    let(:line_item) { build(:line_item, variant: variant, quantity: 2) }

    before { subject.set_preference(:per_kg, 10) }

    it "computes shipping cost for a line item" do
      expect(subject.compute(line_item)).to eq(10 * 2 * 10)
    end

    describe "and with final_weight_volume defined" do
      before { line_item.update_attribute :final_weight_volume, '18000' }

      it "computes fee using final_weight_volume, not the variant weight" do
        expect(subject.compute(line_item)).to eq(10 * 18)
      end

      context "where variant unit is not weight" do
        it "uses both final_weight_volume and weight to calculate fee" do
          line_item.variant.product.update_attribute :variant_unit, 'items'
          expect(subject.compute(line_item)).to eq(180)
        end
      end
    end
  end

  it "computes shipping cost for an object with an order" do
    variant1 = build(:variant, weight: 10)
    variant2 = build(:variant, weight: 5)

    line_item1 = build(:line_item, variant: variant1, quantity: 1)
    line_item2 = build(:line_item, variant: variant2, quantity: 2)

    order = double(:order, line_items: [line_item1, line_item2])
    object_with_order = double(:object_with_order, order: order)

    subject.set_preference(:per_kg, 10)
    expect(subject.compute(object_with_order)).to eq((10 * 1 + 5 * 2) * 10)
  end

  context "when line item final_weight_volume is set" do
    let!(:product) { create(:product, product_attributes) }
    let!(:variant) { create(:variant, variant_attributes.merge(product: product)) }

    let(:calculator) { described_class.new(preferred_per_kg: 6) }
    let(:line_item) do
      build(:line_item, variant: variant, quantity: 2).tap do |object|
        object.send(:calculate_final_weight_volume)
      end
    end

    context "when the product uses weight unit" do
      context "when the product is in g (3g)" do
        let!(:product_attributes) { { variant_unit: "weight", variant_unit_scale: 1.0 } }
        let!(:variant_attributes) { { unit_value: 300.0, weight: 0.30 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(600) # 600g
          line_item.final_weight_volume = 700 # 700g
          expect(calculator.compute(line_item)).to eq(4.2)
        end
      end

      context "when the product is in kg (3kg)" do
        let!(:product_attributes) { { variant_unit: "weight", variant_unit_scale: 1_000.0 } }
        let!(:variant_attributes) { { unit_value: 3_000.0, weight: 3.0 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(6_000) # 6kg
          line_item.final_weight_volume = 7_000 # 7kg
          expect(calculator.compute(line_item)).to eq(42)
        end
      end

      context "when the product is in T (3T)" do
        let!(:product_attributes) { { variant_unit: "weight", variant_unit_scale: 1_000_000.0 } }
        let!(:variant_attributes) { { unit_value: 3_000_000.0, weight: 3_000.0 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(6_000_000) # 6T
          line_item.final_weight_volume = 7_000_000 # 7T
          expect(calculator.compute(line_item)).to eq(42_000)
        end
      end
    end

    context "when the product uses volume unit" do
      context "when the product is in mL (300mL)" do
        let!(:product_attributes) { { variant_unit: "volume", variant_unit_scale: 0.001 } }
        let!(:variant_attributes) { { unit_value: 0.3, weight: 0.25 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(0.6) # 600mL
          line_item.final_weight_volume = 0.7 # 700mL
          expect(calculator.compute(line_item)).to eq(3.50)
        end
      end

      context "when the product is in L (3L)" do
        let!(:product_attributes) { { variant_unit: "volume", variant_unit_scale: 1 } }
        let!(:variant_attributes) { { unit_value: 3.0, weight: 2.5 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(6) # 6L
          line_item.final_weight_volume = 7 # 7L
          expect(calculator.compute(line_item)).to eq(35.00)
        end
      end

      context "when the product is in kL (3kL)" do
        let!(:product_attributes) { { variant_unit: "volume", variant_unit_scale: 1_000 } }
        let!(:variant_attributes) { { unit_value: 3_000.0, weight: 2_500.0 } }

        it "is correct" do
          expect(line_item.final_weight_volume).to eq(6_000) # 6kL
          line_item.final_weight_volume = 7_000 # 7kL
          expect(calculator.compute(line_item)).to eq(34_995)
        end
      end
    end

    context "when the product uses item unit" do
      let!(:product_attributes) { { variant_unit: "items", variant_unit_scale: nil, variant_unit: "pc", display_as: "pc" } }
      let!(:variant_attributes) { { unit_value: 3.0, weight: 2.5, display_as: "pc" } }

      it "is correct" do
        expect(line_item.final_weight_volume).to eq(6) # 6 pcs
        line_item.final_weight_volume = 7 # 7 pcs
        expect(calculator.compute(line_item)).to eq(35.0)
      end
    end
  end
end
