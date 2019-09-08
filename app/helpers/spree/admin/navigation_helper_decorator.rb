module Spree
  module Admin
    module NavigationHelper
      # TEMP: import method until it is re-introduced into Spree.
      def klass_for(name)
        model_name = name.to_s

        ["Spree::#{model_name.classify}", model_name.classify, model_name.tr('_', '/').classify].find(&:safe_constantize).try(:safe_constantize)
      end

      # Make it so that the Reports admin tab can be enabled/disabled through the cancan
      # :report resource, since it does not have a corresponding resource class (unlike
      # eg. Spree::Product).
      def klass_for_with_sym_fallback(name)
        klass = klass_for_without_sym_fallback(name)
        klass ||= name.singularize.to_sym
        klass = :overview if klass == :dashboard
        klass = Spree::Order if klass == :bulk_order_management
        klass = EnterpriseGroup if klass == :group
        klass = VariantOverride if klass == :Inventory
        klass = ProductImport::ProductImporter if klass == :import
        klass = Spree::Admin::ReportsController if klass == :report
        klass
      end
      alias_method_chain :klass_for, :sym_fallback

      # TEMP: override method until it is fixed in Spree.
      def tab_with_cancan_check(*args)
        options = { label: args.first.to_s }
        if args.last.is_a?(Hash)
          options = options.merge(args.last)
        end
        return '' if (klass = klass_for(options[:label])) && cannot?(:admin, klass)
        tab_without_cancan_check(*args)
      end
      alias_method_chain :tab, :cancan_check
    end
  end
end
