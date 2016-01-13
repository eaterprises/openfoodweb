require 'open_food_network/spree_api_key_loader'

module Admin
  class VariantOverridesController < ResourceController
    include OpenFoodNetwork::SpreeApiKeyLoader

    before_filter :load_spree_api_key, only: :index
    before_filter :load_data
    before_filter :load_collection, only: [:bulk_update, :bulk_reset]

    def index
    end


    def bulk_update
      # Ensure we're authorised to update all variant overrides
      @vo_set.collection.each { |vo| authorize! :update, vo }

      if @vo_set.save
        # Return saved VOs with IDs
        render json: @vo_set.collection, each_serializer: Api::Admin::VariantOverrideSerializer
      else
        if @vo_set.errors.present?
          render json: { errors: @vo_set.errors }, status: 400
        else
          render nothing: true, status: 500
        end
      end
    end

    def bulk_reset
      # Ensure we're authorised to update all variant overrides.
      @vo_set.collection.each { |vo| authorize! :bulk_reset, vo }

      # Changed this to use class method instead, to ensure the value in the database is used to reset and not a dirty passed-in value
      #vo_set.collection.map! { |vo| vo = vo.reset_stock! }
      @vo_set.collection.map! { |vo| VariantOverride.reset_stock!(vo.hub,vo.variant) }
      render json: @vo_set.collection, each_serializer: Api::Admin::VariantOverrideSerializer
      if @vo_set.errors.present?
        render json: { errors: @vo_set.errors }, status: 400
      end
    end


    private

    def load_data
      @hubs = OpenFoodNetwork::Permissions.new(spree_current_user).
        variant_override_hubs.by_name

      # Used in JS to look up the name of the producer of each product
      @producers = OpenFoodNetwork::Permissions.new(spree_current_user).
        variant_override_producers

      @hub_permissions = OpenFoodNetwork::Permissions.new(spree_current_user).
        variant_override_enterprises_per_hub
      @variant_overrides = VariantOverride.for_hubs(@hubs)
    end

    def load_collection
      collection_hash = Hash[params[:variant_overrides].each_with_index.map { |vo, i| [i, vo] }]
      @vo_set = VariantOverrideSet.new @variant_overrides, collection_attributes: collection_hash
    end

    def collection
    end

    def collection_actions
      [:index, :bulk_update, :bulk_reset]
    end
  end
end
