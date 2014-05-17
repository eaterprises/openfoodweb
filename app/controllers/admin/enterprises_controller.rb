module Admin
  class EnterprisesController < ResourceController
    before_filter :load_enterprise_set, :only => :index
    before_filter :load_countries, :except => :index
    before_filter :load_methods_and_fees, :only => [:new, :edit]
    create.after :grant_management

    helper 'spree/products'

    def bulk_update
      @enterprise_set = EnterpriseSet.new(params[:enterprise_set])
      if @enterprise_set.save
        redirect_to main_app.admin_enterprises_path, :notice => 'Distributor collection times updated.'
      else
        render :index
      end
    end


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
  end
end
