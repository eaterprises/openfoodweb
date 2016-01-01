require 'open_food_network/enterprise_fee_calculator'
require 'open_food_network/variant_and_line_item_naming'

Spree::Variant.class_eval do
  # Remove method From Spree, so method from the naming module is used instead
  # This file may be double-loaded in delayed job environment, so we check before
  # removing the Spree method to prevent error.
  remove_method :options_text if instance_methods(false).include? :options_text
  include OpenFoodNetwork::VariantAndLineItemNaming


  has_many :exchange_variants, dependent: :destroy
  has_many :exchanges, through: :exchange_variants
  has_many :variant_overrides

  attr_accessible :unit_value, :unit_description, :images_attributes, :display_as, :display_name
  accepts_nested_attributes_for :images

  validates_presence_of :unit_value,
    if: -> v { %w(weight volume).include? v.product.andand.variant_unit }

  validates_presence_of :unit_description,
    if: -> v { v.product.andand.variant_unit.present? && v.unit_value.nil? }

  before_validation :update_weight_from_unit_value, if: -> v { v.product.present? }
  after_save :update_units

  scope :with_order_cycles_inner, joins(exchanges: :order_cycle)

  scope :not_deleted, where(deleted_at: nil)
  scope :in_stock, where('spree_variants.count_on_hand > 0 OR spree_variants.on_demand=?', true)
  scope :in_order_cycle, lambda { |order_cycle|
    with_order_cycles_inner.
    merge(Exchange.outgoing).
    where('order_cycles.id = ?', order_cycle).
    select('DISTINCT spree_variants.*')
  }

  scope :for_distribution, lambda { |order_cycle, distributor|
    where('spree_variants.id IN (?)', order_cycle.variants_distributed_by(distributor))
  }

  # Define sope as class method to allow chaining with other scopes filtering id.
  # In Rails 3, merging two scopes on the same column will consider only the last scope.
  def self.in_distributor(distributor)
    where(id: ExchangeVariant.select(:variant_id).
              joins(:exchange).
              where('exchanges.incoming = ? AND exchanges.receiver_id = ?', false, distributor)
         )
  end

  def self.indexed
    Hash[
      scoped.map { |v| [v.id, v] }
    ]
  end


  def price_with_fees(distributor, order_cycle)
    price + fees_for(distributor, order_cycle)
  end

  def fees_for(distributor, order_cycle)
    OpenFoodNetwork::EnterpriseFeeCalculator.new(distributor, order_cycle).fees_for self
  end

  def fees_by_type_for(distributor, order_cycle)
    OpenFoodNetwork::EnterpriseFeeCalculator.new(distributor, order_cycle).fees_by_type_for self
  end

  def delete
    if product.variants == [self] # Only variant left on product
      errors.add :product, "must have at least one variant"
      false
    else
      transaction do
        self.update_column(:deleted_at, Time.zone.now)
        ExchangeVariant.where(variant_id: self).destroy_all
        self
      end
    end
  end

  private

  def update_weight_from_unit_value
    self.weight = weight_from_unit_value if self.product.variant_unit == 'weight' && unit_value.present?
  end
end
