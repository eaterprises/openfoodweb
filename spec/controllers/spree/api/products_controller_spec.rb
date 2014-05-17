require 'spec_helper'
require 'spree/api/testing_support/helpers'

module Spree
  describe Spree::Api::ProductsController do
    include Spree::Api::TestingSupport::Helpers
    render_views

    let(:supplier) { FactoryGirl.create(:supplier_enterprise) }
    let!(:product1) { FactoryGirl.create(:product, supplier: supplier) }
    let!(:product2) { FactoryGirl.create(:product, supplier: supplier) }
    let!(:product3) { FactoryGirl.create(:product, supplier: supplier) }
    let(:attributes) { [:id, :name, :supplier, :price, :on_hand, :available_on, :permalink_live] }
    let(:unit_attributes) { [:id, :name, :group_buy_unit_size, :variant_unit] }

    before do
      stub_authentication!
      Spree.user_class.stub :find_by_spree_api_key => current_api_user
    end

    context "as a normal user" do
      sign_in_as_user!

      it "should deny me access to managed products" do
        spree_get :managed, { :template => 'bulk_index', :format => :json }
        assert_unauthorized!
      end
    end

    context "as an enterprise user" do
      sign_in_as_enterprise_user! [:supplier]

      before :each do
        spree_get :index, { :template => 'bulk_index', :format => :json }
      end

      it "retrieves a list of managed products" do
        spree_get :managed, { :template => 'bulk_index', :format => :json }
        keys = json_response.first.keys.map{ |key| key.to_sym }
        attributes.all?{ |attr| keys.include? attr }.should == true
      end
    end

    context "as an administrator" do
      sign_in_as_admin!

      it "retrieves a list of managed products" do
        spree_get :managed, { :template => 'bulk_index', :format => :json }
        keys = json_response.first.keys.map{ |key| key.to_sym }
        attributes.all?{ |attr| keys.include? attr }.should == true
      end

      it "retrieves a list of products with appropriate attributes" do
        spree_get :index, { :template => 'bulk_index', :format => :json }
        keys = json_response.first.keys.map{ |key| key.to_sym }
        attributes.all?{ |attr| keys.include? attr }.should == true
      end

      it "retrieves a list of products with attributes relating to units" do
        spree_get :show, { :id => product1.id, :template => "units_show", :format => :json }
        keys = json_response.keys.map{ |key| key.to_sym }
        unit_attributes.all?{ |attr| keys.include? attr }.should == true
      end

      it "sorts products in ascending id order" do
        spree_get :index, { :template => 'bulk_index', :format => :json }
        ids = json_response.map{ |product| product['id'] }
        ids[0].should < ids[1]
        ids[1].should < ids[2]
      end

      it "formats available_on to 'yyyy-mm-dd hh:mm'" do
        spree_get :index, { :template => 'bulk_index', :format => :json }
        json_response.map{ |product| product['available_on'] }.all?{ |a| a.match("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$") }.should == true
      end

      it "returns permalink as permalink_live" do
        spree_get :index, { :template => 'bulk_index', :format => :json }
        json_response.detect{ |product| product['id'] == product1.id }['permalink_live'].should == product1.permalink
      end

      it "should allow available_on to be nil" do

        spree_get :index, { :template => 'bulk_index', :format => :json }
        json_response.size.should == 3

        product4 = FactoryGirl.create(:product)
        product4.available_on = nil
        product4.save!

        spree_get :index, { :template => 'bulk_index', :format => :json }
        json_response.size.should == 4
      end
    end
  end
end
