# frozen_string_literal: false

module Spree
  class DefaultTaxZoneValidator < ActiveModel::Validator
    def validate(record)
      return unless record.included_in_price

      return if Zone.default_tax

      record.errors.add(:included_in_price, Spree.t("errors.messages.included_price_validation"))
    end
  end
end

module Spree
  class TaxRate < ActiveRecord::Base
    acts_as_paranoid
    include Spree::Core::CalculatedAdjustments

    has_many :adjustments, as: :source, dependent: :destroy
    belongs_to :zone, class_name: "Spree::Zone"
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    validates :amount, presence: true, numericality: true
    validates :tax_category_id, presence: true
    validates_with DefaultTaxZoneValidator

    scope :by_zone, ->(zone) { where(zone_id: zone) }

    # Gets the array of TaxRates appropriate for the specified order
    def self.match(order)
      return [] if order.distributor && !order.distributor.charges_sales_tax
      return [] unless order.tax_zone

      all.select do |rate|
        rate.zone == order.tax_zone || rate.zone.contains?(order.tax_zone) || rate.zone.default_tax
      end
    end

    def self.adjust(order, items)
      match(order).each do |rate|
        items.each { |item| rate.adjust(order, item) }
      end
    end

    # For VAT, the default rate is the rate that is configured for the default category
    # It is needed for every price calculation (as all customer facing prices include VAT)
    # Here we return the actual amount, which may be 0 in case of wrong setup, but is never nil
    def self.default
      category = TaxCategory.includes(:tax_rates).find_by(is_default: true)
      return 0 unless category

      address ||= Address.new(country_id: Spree::Config[:default_country_id])
      rate = category.tax_rates.detect { |tax_rate| tax_rate.zone.include? address }.try(:amount)

      rate || 0
    end

    # Creates necessary tax adjustments for the order.
    def adjust(order, item)
      item.adjustments.tax.delete_all
      amount = compute_amount(item)
      return if amount.zero?

      if amount.negative?
        label = Spree.t(:refund) + ' ' + create_label
      end

      self.adjustments.create!(
        {
          adjustable: item,
          amount: amount,
          order: order,
          label: label || create_label
        }
      )
    end

    # This method is used by Adjustment#update to recalculate the cost.
    def compute_amount(item)
      if included_in_price
        if Zone.default_tax.contains? item.order.tax_zone
          calculator.compute(item)
        else
          # In this case, it's a refund.
          calculator.compute(item) * - 1
        end
      else
        calculator.compute(item)
      end
    end

    # Manually apply a TaxRate to a particular amount. TaxRates normally compute against
    # LineItems or Orders, so we mock out a line item here to fit the interface
    # that our calculator (usually DefaultTax) expects.
    def compute_tax(amount)
      line_item = LineItem.new quantity: 1
      line_item.tax_category = tax_category
      line_item.define_singleton_method(:price) { amount }

      # Tax on adjustments (represented by the included_tax field) is always inclusive of
      # tax. However, there's nothing to stop an admin from setting one up with a tax rate
      # that's marked as not inclusive of tax, and that would result in the DefaultTax
      # calculator generating a slightly incorrect value. Therefore, we treat the tax
      # rate as inclusive of tax for the calculations below, regardless of its original
      # setting.
      with_tax_included_in_price do
        calculator.compute line_item
      end
    end

    private

    def create_label
      label = ""
      label << (name.presence || tax_category.name) + " "
      label << (show_rate_in_label? ? "#{amount * 100}%" : "")
    end

    def with_tax_included_in_price
      old_included_in_price = included_in_price

      self.included_in_price = true
      calculator.calculable.included_in_price = true

      result = yield
    ensure
      self.included_in_price = old_included_in_price
      calculator.calculable.included_in_price = old_included_in_price

      result
    end
  end
end
