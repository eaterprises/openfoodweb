module Admin
  class EnterprisesController < ResourceController
    before_filter :load_enterprise_set, :only => :index
    before_filter :load_countries, :except => :index
    before_filter :load_methods_and_fees, :only => [:new, :edit, :update, :create]
    create.after :grant_management

    helper 'spree/products'


    def bulk_update
      @enterprise_set = EnterpriseSet.new(params[:enterprise_set])
      if @enterprise_set.save
        flash[:success] = 'Enterprises updated successfully'
        redirect_to main_app.admin_enterprises_path
      else
        render :index
      end
    end


    protected

    def build_resource_with_address
      enterprise = build_resource_without_address
      enterprise.address = Spree::Address.new
      enterprise.address.country = Spree::Country.find_by_id(Spree::Config[:default_country_id])
      enterprise
    end
    alias_method_chain :build_resource, :address


    private

    # When an enterprise user creates another enterprise, it is granted management
    # permission for it
    def grant_management
      unless spree_current_user.has_spree_role? 'admin'
        spree_current_user.enterprise_roles.create(enterprise: @object)
      end
    end

    def load_enterprise_set
      @enterprise_set = EnterpriseSet.new :collection => collection
    end

    def load_countries
      @countries = Spree::Country.order(:name)
    end

    def collection
      Enterprise.managed_by(spree_current_user).order('is_distributor DESC, is_primary_producer ASC, name')
    end

    def collection_actions
      [:index, :bulk_update]
    end

    def load_methods_and_fees
      @payment_methods = Spree::PaymentMethod.managed_by(spree_current_user).sort_by!{ |pm| [(@enterprise.payment_methods.include? pm) ? 0 : 1, pm.name] }
      @shipping_methods = Spree::ShippingMethod.managed_by(spree_current_user).sort_by!{ |sm| [(@enterprise.shipping_methods.include? sm) ? 0 : 1, sm.name] }
      @enterprise_fees = EnterpriseFee.managed_by(spree_current_user).for_enterprise(@enterprise).order(:fee_type, :name).all
    end

    # Overriding method on Spree's resource controller
    def location_after_save
      if params[:enterprise].key? :producer_properties_attributes
        main_app.admin_enterprises_path
      else
        main_app.edit_admin_enterprise_path(@enterprise)
      end
    end
  end
end
