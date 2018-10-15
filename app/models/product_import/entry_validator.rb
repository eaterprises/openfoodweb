# This class handles a number of custom validation processes that take place during product import,
# as a spreadsheet entry is checked to see if it is a valid product, variant, or inventory item.
# It also handles error messages and user feedback for the validation process.

module ProductImport
  class EntryValidator
    def initialize(current_user, import_time, spreadsheet_data, editable_enterprises, inventory_permissions, reset_counts, import_settings)
      @current_user = current_user
      @import_time = import_time
      @spreadsheet_data = spreadsheet_data
      @editable_enterprises = editable_enterprises
      @inventory_permissions = inventory_permissions
      @reset_counts = reset_counts
      @import_settings = import_settings
    end

    def self.non_updatable_fields
      {
        category: :primary_taxon_id,
        description: :description,
        unit_type: :variant_unit_scale,
        variant_unit_name: :variant_unit_name,
        tax_category: :tax_category_id,
        shipping_category: :shipping_category_id
      }
    end

    def validate_all(entries)
      entries.each do |entry|
        supplier_validation(entry)
        unit_fields_validation(entry)

        next if entry.supplier_id.blank?

        if import_into_inventory?
          producer_validation(entry)
          inventory_validation(entry)
        else
          category_validation(entry)
          tax_and_shipping_validation(entry, 'tax', entry.tax_category, @spreadsheet_data.tax_index)
          tax_and_shipping_validation(entry, 'shipping', entry.shipping_category, @spreadsheet_data.shipping_index)
          product_validation(entry)
        end
      end
    end

    def mark_as_new_variant(entry, product_id)
      new_variant = Spree::Variant.new(entry.attributes.except('id', 'product_id'))
      new_variant.product_id = product_id
      check_on_hand_nil(entry, new_variant)

      if new_variant.valid?
        entry.product_object = new_variant
        entry.validates_as = 'new_variant' unless entry.errors?
      else
        mark_as_invalid(entry, product_validations: new_variant.errors)
      end
    end

    private

    def supplier_validation(entry)
      return if name_presence_error entry
      return if enterprise_not_found_error entry
      return if permissions_error entry
      return if primary_producer_error entry

      entry.supplier_id = @spreadsheet_data.suppliers_index[entry.supplier][:id]
    end

    def name_presence_error(entry)
      return if entry.supplier.present?
      mark_as_invalid(entry, attribute: "supplier", error: I18n.t(:error_required))
      true
    end

    def enterprise_not_found_error(entry)
      return if @spreadsheet_data.suppliers_index[entry.supplier][:id]
      mark_as_invalid(entry, attribute: "supplier", error: I18n.t(:error_not_found_in_database, name: entry.supplier))
      true
    end

    def permissions_error(entry)
      return if permission_by_name?(entry.supplier)
      mark_as_invalid(entry, attribute: "supplier", error: I18n.t(:error_no_permission_for_enterprise, name: entry.supplier))
      true
    end

    def primary_producer_error(entry)
      return if import_into_inventory?
      return if @spreadsheet_data.suppliers_index[entry.supplier][:is_primary_producer]
      mark_as_invalid(entry, attribute: "supplier", error: I18n.t(:error_not_primary_producer, name: entry.supplier))
      true
    end

    def unit_fields_validation(entry)
      unit_types = ['g', 'kg', 't', 'ml', 'l', 'kl', '']

      unless entry.units && entry.units.present?
        mark_as_invalid(entry, attribute: 'units', error: I18n.t('admin.product_import.model.blank'))
      end

      return if import_into_inventory?

      # unit_type must be valid type
      if entry.unit_type && entry.unit_type.present?
        unit_type = entry.unit_type.to_s.strip.downcase
        mark_as_invalid(entry, attribute: 'unit_type', error: I18n.t('admin.product_import.model.incorrect_value')) unless unit_types.include?(unit_type)
        return
      end

      # variant_unit_name must be present if unit_type not present
      mark_as_invalid(entry, attribute: 'variant_unit_name', error: I18n.t('admin.product_import.model.conditional_blank')) unless entry.variant_unit_name && entry.variant_unit_name.present?
    end

    def producer_validation(entry)
      producer_name = entry.producer

      if producer_name.blank?
        mark_as_invalid(entry, attribute: "producer", error: I18n.t('admin.product_import.model.blank'))
        return
      end

      unless @spreadsheet_data.producers_index[producer_name]
        mark_as_invalid(entry, attribute: "producer", error: "\"#{producer_name}\" #{I18n.t('admin.product_import.model.not_found')}")
        return
      end

      unless inventory_permission?(entry.supplier_id, @spreadsheet_data.producers_index[producer_name])
        mark_as_invalid(entry, attribute: "producer", error: "\"#{producer_name}\": #{I18n.t('admin.product_import.model.inventory_no_permission')}")
        return
      end

      entry.producer_id = @spreadsheet_data.producers_index[producer_name]
    end

    def inventory_validation(entry)
      products = Spree::Product.where(supplier_id: entry.producer_id, name: entry.name, deleted_at: nil)

      if products.empty?
        mark_as_invalid(entry, attribute: 'name', error: I18n.t('admin.product_import.model.no_product'))
        return
      end

      products.flat_map(&:variants).each do |existing_variant|
        unit_scale = existing_variant.product.variant_unit_scale
        unscaled_units = entry.unscaled_units || 0
        entry.unit_value = unscaled_units * unit_scale

        if entry_matches_existing_variant?(entry, existing_variant)
          variant_override = create_inventory_item(entry, existing_variant)
          return validate_inventory_item(entry, variant_override)
        end
      end

      mark_as_invalid(entry, attribute: 'product', error: I18n.t('admin.product_import.model.not_found'))
    end

    def entry_matches_existing_variant?(entry, existing_variant)
      existing_variant.display_name == entry.display_name && existing_variant.unit_value == entry.unit_value.to_f
    end

    def category_validation(entry)
      category_name = entry.category

      if category_name.blank?
        mark_as_invalid(entry, attribute: "category", error: I18n.t(:error_required))
        return
      end

      if @spreadsheet_data.categories_index[category_name]
        entry.primary_taxon_id = @spreadsheet_data.categories_index[category_name]
      else
        mark_as_invalid(entry, attribute: "category", error: I18n.t(:error_not_found_in_database, name: category_name))
      end
    end

    def tax_and_shipping_validation(entry, type, category, index)
      return if category.blank?

      if index.key? category
        entry.public_send("#{type}_category_id=", index[category])
      else
        mark_as_invalid(entry, attribute: "#{type}_category", error: I18n.t('admin.product_import.model.not_found'))
      end
    end

    def product_validation(entry)
      products = Spree::Product.where(supplier_id: entry.supplier_id, name: entry.name, deleted_at: nil)

      if products.empty?
        mark_as_new_product(entry)
        return
      end

      products.each { |product| product_field_errors(entry, product) }

      products.flat_map(&:variants).each do |existing_variant|
        if entry_matches_existing_variant?(entry, existing_variant) && existing_variant.deleted_at.nil?
          return mark_as_existing_variant(entry, existing_variant)
        end
      end

      mark_as_new_variant(entry, products.first.id)
    end

    def mark_as_new_product(entry)
      new_product = Spree::Product.new
      new_product.assign_attributes(entry.attributes.except('id'))

      if new_product.valid?
        entry.validates_as = 'new_product' unless entry.errors?
      else
        mark_as_invalid(entry, product_validations: new_product.errors)
      end
    end

    def mark_as_existing_variant(entry, existing_variant)
      existing_variant.assign_attributes(entry.attributes.except('id', 'product_id'))
      check_on_hand_nil(entry, existing_variant)

      if existing_variant.valid?
        entry.product_object = existing_variant
        entry.validates_as = 'existing_variant' unless entry.errors?
        updates_count_per_supplier(entry.supplier_id) unless entry.errors?
      else
        mark_as_invalid(entry, product_validations: existing_variant.errors)
      end
    end

    def product_field_errors(entry, existing_product)
      EntryValidator.non_updatable_fields.each do |display_name, attribute|
        next if attributes_match?(attribute, existing_product, entry) || attributes_blank?(attribute, existing_product, entry)
        mark_as_invalid(entry, attribute: display_name, error: I18n.t('admin.product_import.model.not_updatable'))
      end
    end

    def attributes_match?(attribute, existing_product, entry)
      existing_product.public_send(attribute) == entry.public_send(attribute)
    end

    def attributes_blank?(attribute, existing_product, entry)
      existing_product.public_send(attribute).blank? && entry.public_send(attribute).blank?
    end

    def permission_by_name?(supplier_name)
      @editable_enterprises.key?(supplier_name)
    end

    def permission_by_id?(supplier_id)
      @editable_enterprises.value?(Integer(supplier_id))
    end

    def inventory_permission?(supplier_id, producer_id)
      @current_user.admin? || ( @inventory_permissions[supplier_id] && @inventory_permissions[supplier_id].include?(producer_id) )
    end

    def mark_as_invalid(entry, options = {})
      entry.errors.add(options[:attribute], options[:error]) if options[:attribute] && options[:error]
      entry.product_validations = options[:product_validations] if options[:product_validations]
    end

    def import_into_inventory?
      @import_settings[:settings]['import_into'] == 'inventories'
    end

    def validate_inventory_item(entry, variant_override)
      if variant_override.valid? && !entry.errors?
        mark_as_inventory_item(entry, variant_override)
      else
        mark_as_invalid(entry, product_validations: variant_override.errors)
      end
    end

    def create_inventory_item(entry, existing_variant)
      existing_variant_override = VariantOverride.where(variant_id: existing_variant.id, hub_id: entry.supplier_id).first

      variant_override = existing_variant_override || VariantOverride.new(variant_id: existing_variant.id, hub_id: entry.supplier_id)
      variant_override.assign_attributes(count_on_hand: entry.on_hand, import_date: @import_time)
      check_on_hand_nil(entry, variant_override)
      variant_override.assign_attributes(entry.attributes.slice('price', 'on_demand'))

      variant_override
    end

    def mark_as_inventory_item(entry, variant_override)
      if variant_override.id
        entry.validates_as = 'existing_inventory_item'
        entry.product_object = variant_override
        updates_count_per_supplier(entry.supplier_id) unless entry.errors?
      else
        entry.validates_as = 'new_inventory_item'
        entry.product_object = variant_override
      end
    end

    def updates_count_per_supplier(supplier_id)
      if @reset_counts[supplier_id] && @reset_counts[supplier_id][:updates_count]
        @reset_counts[supplier_id][:updates_count] += 1
      else
        @reset_counts[supplier_id] = { updates_count: 1 }
      end
    end

    def check_on_hand_nil(entry, object)
      return if entry.on_hand.present?

      object.on_hand = 0 if object.respond_to?(:on_hand)
      object.count_on_hand = 0 if object.respond_to?(:count_on_hand)
      entry.on_hand_nil = true
    end
  end
end
