require 'spec_helper'

feature %q{
  As an Administrator
  I want to be able to manage products in bulk
} , js: true do
  include AuthenticationWorkflow
  include WebHelper
  
  describe "listing products" do
    before :each do
      login_to_admin_section
    end

    it "displays a list of products" do
      p1 = FactoryGirl.create(:product)
      p2 = FactoryGirl.create(:product)

      visit '/admin/products/bulk_edit'

      page.should have_field "product_name", with: p1.name, :visible => true
      page.should have_field "product_name", with: p2.name, :visible => true
    end

    it "displays a message when number of products is zero" do
      visit '/admin/products/bulk_edit'

      page.should have_text "No matching products found."
    end

    pending "displays a message when number of products is too great" do
      501.times { FactoryGirl.create(:simple_product) }

      visit '/admin/products/bulk_edit'

      page.should have_text "Search returned too many products to display (500+), please apply more search filters to reduce the number of matching products"
    end

    it "displays pagination information" do
      p1 = FactoryGirl.create(:product)
      p2 = FactoryGirl.create(:product)

      visit '/admin/products/bulk_edit'

      page.should have_text "Displaying 1-2 of 2 products"
    end

    it "displays a select box for suppliers, with the appropriate supplier selected" do
      s1 = FactoryGirl.create(:supplier_enterprise)
      s2 = FactoryGirl.create(:supplier_enterprise)
      s3 = FactoryGirl.create(:supplier_enterprise)
      p1 = FactoryGirl.create(:product, supplier: s2)
      p2 = FactoryGirl.create(:product, supplier: s3)

      visit '/admin/products/bulk_edit'

      page.should have_select "supplier", with_options: [s1.name,s2.name,s3.name], selected: s2.name
      page.should have_select "supplier", with_options: [s1.name,s2.name,s3.name], selected: s3.name
    end

    it "displays a date input for available_on for each product, formatted to yyyy-mm-dd hh:mm:ss" do
      p1 = FactoryGirl.create(:product, available_on: Date.today)
      p2 = FactoryGirl.create(:product, available_on: Date.today-1)

      visit '/admin/products/bulk_edit'
      first("div.option_tab_titles h6", :text => "Toggle Columns").click
      first("li.column-list-item", text: "Available On").click

      page.should have_field "available_on", with: p1.available_on.strftime("%F %T")
      page.should have_field "available_on", with: p2.available_on.strftime("%F %T")
    end

    it "displays a price input for each product without variants (ie. for master variant)" do
      p1 = FactoryGirl.create(:product)
      p2 = FactoryGirl.create(:product)
      p3 = FactoryGirl.create(:product)
      v = FactoryGirl.create(:variant, product: p3)

      p1.update_attribute :price, 22.0
      p2.update_attribute :price, 44.0
      p3.update_attribute :price, 66.0

      visit '/admin/products/bulk_edit'

      page.should     have_field "price", with: "22.0"
      page.should     have_field "price", with: "44.0"
      page.should_not have_field "price", with: "66.0", visible: true
    end
    
    it "displays an on hand count input for each product (ie. for master variant) if no regular variants exist" do
      p1 = FactoryGirl.create(:product)
      p2 = FactoryGirl.create(:product)
      p1.on_hand = 15
      p2.on_hand = 12
      p1.save!
      p2.save!

      visit '/admin/products/bulk_edit'

      page.should_not have_selector "span[name='on_hand']", text: "0"
      page.should have_field "on_hand", with: "15"
      page.should have_field "on_hand", with: "12"
    end
    
    it "displays an on hand count in a span for each product (ie. for master variant) if other variants exist" do
      p1 = FactoryGirl.create(:product)
      p2 = FactoryGirl.create(:product)
      v1 = FactoryGirl.create(:variant, product: p1, is_master: false, on_hand: 4)
      p1.on_hand = 15
      p2.on_hand = 12
      p1.save!
      p2.save!

      visit '/admin/products/bulk_edit'

      page.should_not have_field "on_hand", with: "15"
      page.should have_selector "span[name='on_hand']", text: "4"
      page.should have_field "on_hand", with: "12"
    end

    it "displays 'on demand' for the on hand count when the product is available on demand" do
      p1 = FactoryGirl.create(:product, on_demand: true)
      p1.master.on_demand = true; p1.master.save!

      visit '/admin/products/bulk_edit'

      page.should     have_selector "span[name='on_hand']", text: "On demand"
      page.should_not have_field "on_hand", visible: true
    end

    it "displays 'on demand' for any variant that is available on demand" do
      p1 = FactoryGirl.create(:product)
      v1 = FactoryGirl.create(:variant, product: p1, is_master: false, on_hand: 4)
      v2 = FactoryGirl.create(:variant, product: p1, is_master: false, on_hand: 0, on_demand: true)

      visit '/admin/products/bulk_edit'
      first("a.view-variants").trigger('click')

      page.should_not have_selector "span[name='on_hand']", text: "On demand", visible: true
      page.should     have_field "variant_on_hand", with: "4"
      page.should_not have_field "variant_on_hand", with: "", visible: true
      page.should     have_selector "span[name='variant_on_hand']", text: "On demand"
    end

    it "displays a select box for the unit of measure for the product's variants" do
      p = FactoryGirl.create(:product, variant_unit: 'weight', variant_unit_scale: 1, variant_unit_name: '')

      visit '/admin/products/bulk_edit'

      page.should have_select "variant_unit_with_scale", selected: "Weight (g)"
    end

    it "displays a text field for the item name when unit is set to 'Items'" do
      p = FactoryGirl.create(:product, variant_unit: 'items', variant_unit_scale: nil, variant_unit_name: 'packet')

      visit '/admin/products/bulk_edit'

      page.should have_select "variant_unit_with_scale", selected: "Items"
      page.should have_field "variant_unit_name", with: "packet"
    end
  end
  
  describe "listing variants" do
    before :each do
      login_to_admin_section
    end

    it "displays a list of variants for each product" do
      v1 = FactoryGirl.create(:variant, display_name: "something1" )
      v2 = FactoryGirl.create(:variant, display_name: "something2" )

      visit '/admin/products/bulk_edit'
      page.should have_selector "a.view-variants"
      all("a.view-variants").each { |e| e.trigger('click') }

      page.should have_field "product_name", with: v1.product.name
      page.should have_field "product_name", with: v2.product.name
      page.should have_field "variant_display_name", with: v1.display_name
      page.should have_field "variant_display_name", with: v2.display_name
    end

    it "displays an on_hand input (for each variant) for each product" do
      p1 = FactoryGirl.create(:product)
      v1 = FactoryGirl.create(:variant, product: p1, is_master: false, on_hand: 15)
      v2 = FactoryGirl.create(:variant, product: p1, is_master: false, on_hand: 6)

      visit '/admin/products/bulk_edit'
      all("a.view-variants").each { |e| e.trigger('click') }

      page.should have_selector "span[name='on_hand']", text: "21"
      page.should have_field "variant_on_hand", with: "15"
      page.should have_field "variant_on_hand", with: "6"
    end
    
   
    it "displays a price input (for each variant) for each product" do
      p1 = FactoryGirl.create(:product, price: 2.0)
      v1 = FactoryGirl.create(:variant, product: p1, is_master: false, price: 12.75)
      v2 = FactoryGirl.create(:variant, product: p1, is_master: false, price: 2.50)

      visit '/admin/products/bulk_edit'
      all("a.view-variants").each { |e| e.trigger('click') }

      page.should have_field "price", with: "2.0", visible: false
      page.should have_field "variant_price", with: "12.75"
      page.should have_field "variant_price", with: "2.5"
    end

    it "displays a unit value field (for each variant) for each product" do
      p1 = FactoryGirl.create(:product, price: 2.0, variant_unit: "weight", variant_unit_scale: "1000")
      v1 = FactoryGirl.create(:variant, product: p1, is_master: false, price: 12.75, unit_value: 1200, unit_description: "(small bag)", display_as: "bag")
      v2 = FactoryGirl.create(:variant, product: p1, is_master: false, price: 2.50, unit_value: 4800, unit_description: "(large bag)", display_as: "bin")

      visit '/admin/products/bulk_edit'
      all("a.view-variants").each { |e| e.trigger('click') }

      page.should have_field "variant_unit_value_with_description", with: "1.2 (small bag)"
      page.should have_field "variant_unit_value_with_description", with: "4.8 (large bag)"
      page.should have_field "variant_display_as", with: "bag"
      page.should have_field "variant_display_as", with: "bin"
    end
  end


  scenario "creating a new product" do
    s = FactoryGirl.create(:supplier_enterprise)
    d = FactoryGirl.create(:distributor_enterprise)
    taxon = create(:taxon)

    login_to_admin_section

    visit '/admin/products/bulk_edit'

    find("a", text: "NEW PRODUCT").click
    page.should have_content 'NEW PRODUCT'

    fill_in 'product_name', :with => 'Big Bag Of Apples'
    select(s.name, :from => 'product_supplier_id')
    fill_in 'product_price', :with => '10.00'
    select taxon.name, from: 'product_primary_taxon_id'
    click_button 'Create'

    URI.parse(current_url).path.should == '/admin/products/bulk_edit'
    flash_message.should == 'Product "Big Bag Of Apples" has been successfully created!'
    page.should have_field "product_name", with: 'Big Bag Of Apples'
  end


  scenario "creating new variants" do
    # Given a product without variants or a unit
    p = FactoryGirl.create(:product, variant_unit: nil, variant_unit_scale: nil)
    login_to_admin_section
    visit '/admin/products/bulk_edit'

    # I should not see an add variant button
    page.should_not have_selector 'a.add-variant', visible: true

    # When I set the unit
    select "Weight (kg)", from: "variant_unit_with_scale"

    # I should see an add variant button
    page.should have_selector 'a.add-variant', visible: true

    # When I add three variants
    page.find('a.add-variant', visible: true).trigger('click')
    page.find('a.add-variant', visible: true).trigger('click')
    page.find('a.add-variant', visible: true).trigger('click')

    # They should be added, and should see no edit buttons
    page.all("tr.variant").count.should == 3
    page.should_not have_selector "a.edit-variant", visible: true

    # When I remove two, they should be removed
    page.all('a.delete-variant').first.click
    page.all('a.delete-variant').first.click
    page.all("tr.variant").count.should == 1

    # When I fill out variant details and hit update
    fill_in "variant_display_name", with: "Case of 12 Bottles"
    fill_in "variant_unit_value_with_description", with: "4000 (12x250 mL bottles)"
    fill_in "variant_display_as", with: "Case"
    fill_in "variant_price", with: "4.0"
    fill_in "variant_on_hand", with: "10"
    click_button 'Update'

    page.find("span#update-status-message").should have_content "Update complete"

    # Then I should see edit buttons for the new variant
    page.should have_selector "a.edit-variant", visible: true

    # And the variants should be saved
    visit '/admin/products/bulk_edit'
    page.should have_selector "a.view-variants"
    first("a.view-variants").trigger('click')

    page.should have_field "variant_display_name", with: "Case of 12 Bottles"
    page.should have_field "variant_unit_value_with_description", with: "4000 (12x250 mL bottles)"
    page.should have_field "variant_display_as", with: "Case"
    page.should have_field "variant_price", with: "4.0"
    page.should have_field "variant_on_hand", with: "10"
  end


  scenario "updating a product with no variants (except master)" do
    s1 = FactoryGirl.create(:supplier_enterprise)
    s2 = FactoryGirl.create(:supplier_enterprise)
    p = FactoryGirl.create(:product, supplier: s1, available_on: Date.today, variant_unit: 'volume', variant_unit_scale: 1)
    p.price = 10.0
    p.on_hand = 6;
    p.save!

    login_to_admin_section

    visit '/admin/products/bulk_edit'
    
    first("div.option_tab_titles h6", :text => "Toggle Columns").click
    first("li.column-list-item", text: "Available On").click

    page.should have_field "product_name", with: p.name
    page.should have_select "supplier", selected: s1.name
    page.should have_field "available_on", with: p.available_on.strftime("%F %T")
    page.should have_field "price", with: "10.0"
    page.should have_select "variant_unit_with_scale", selected: "Volume (L)"
    page.should have_field "on_hand", with: "6"

    fill_in "product_name", with: "Big Bag Of Potatoes"
    select(s2.name, :from => 'supplier')
    fill_in "available_on", with: (Date.today-3).strftime("%F %T")
    fill_in "price", with: "20"
    select "Weight (kg)", from: "variant_unit_with_scale"
    fill_in "on_hand", with: "18"
    fill_in "display_as", with: "Big Bag"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    visit '/admin/products/bulk_edit'

    page.should have_field "product_name", with: "Big Bag Of Potatoes"
    page.should have_select "supplier", selected: s2.name
    page.should have_field "available_on", with: (Date.today-3).strftime("%F %T"), visible: false
    page.should have_field "price", with: "20.0"
    page.should have_select "variant_unit_with_scale", selected: "Weight (kg)"
    page.should have_field "on_hand", with: "18"
    page.should have_field "display_as", with: "Big Bag"
  end
  
  scenario "updating a product with a variant unit of 'items'" do
    p = FactoryGirl.create(:product, variant_unit: 'weight', variant_unit_scale: 1000)

    login_to_admin_section

    visit '/admin/products/bulk_edit'

    page.should have_select "variant_unit_with_scale", selected: "Weight (kg)"

    select "Items", from: "variant_unit_with_scale"
    fill_in "variant_unit_name", with: "loaf"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    visit '/admin/products/bulk_edit'

    page.should have_select "variant_unit_with_scale", selected: "Items"
    page.should have_field "variant_unit_name", with: "loaf"
  end

  scenario "setting a variant unit on a product that has none" do
    p = FactoryGirl.create(:product, variant_unit: nil, variant_unit_scale: nil)
    v = FactoryGirl.create(:variant, product: p, unit_value: nil, unit_description: nil)

    login_to_admin_section

    visit '/admin/products/bulk_edit'

    page.should have_select "variant_unit_with_scale", selected: ''

    select "Weight (kg)", from: "variant_unit_with_scale"
    first("a.view-variants").trigger('click')
    fill_in "variant_unit_value_with_description", with: '123 abc'

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    visit '/admin/products/bulk_edit'
    first("a.view-variants").trigger('click')

    page.should have_select "variant_unit_with_scale", selected: "Weight (kg)"
    page.should have_field "variant_unit_value_with_description", with: "123 abc"
  end

  describe "setting the master unit value for a product without variants" do
    it "sets the master unit value" do
      p = FactoryGirl.create(:product, variant_unit: nil, variant_unit_scale: nil)

      login_to_admin_section

      visit '/admin/products/bulk_edit'

      page.should have_select "variant_unit_with_scale", selected: ''
      page.should_not have_field "master_unit_value_with_description", visible: true

      select "Weight (kg)", from: "variant_unit_with_scale"
      fill_in "master_unit_value_with_description", with: '123 abc'

      click_button 'Update'
      page.find("span#update-status-message").should have_content "Update complete"

      visit '/admin/products/bulk_edit'

      page.should have_select "variant_unit_with_scale", selected: "Weight (kg)"
      page.should have_field "master_unit_value_with_description", with: "123 abc"

      p.reload
      p.variant_unit.should == 'weight'
      p.variant_unit_scale.should == 1000
      p.master.unit_value.should == 123000
      p.master.unit_description.should == 'abc'
    end

    it "does not show the field when the product has variants" do
      p = FactoryGirl.create(:product, variant_unit: nil, variant_unit_scale: nil)
      v = FactoryGirl.create(:variant, product: p, unit_value: nil, unit_description: nil)

      login_to_admin_section

      visit '/admin/products/bulk_edit'

      select "Weight (kg)", from: "variant_unit_with_scale"
      page.should_not have_field "master_unit_value_with_description", visible: true
    end
  end


  scenario "updating a product with variants" do
    s1 = FactoryGirl.create(:supplier_enterprise)
    s2 = FactoryGirl.create(:supplier_enterprise)
    p = FactoryGirl.create(:product, supplier: s1, available_on: Date.today, variant_unit: 'volume', variant_unit_scale: 0.001)
    v = FactoryGirl.create(:variant, product: p, price: 3.0, on_hand: 9, unit_value: 0.25, unit_description: '(bottle)')

    login_to_admin_section

    visit '/admin/products/bulk_edit'
    page.should have_selector "a.view-variants"
    first("a.view-variants").trigger('click')

    page.should have_field "variant_price", with: "3.0"
    page.should have_field "variant_unit_value_with_description", with: "250 (bottle)"
    page.should have_field "variant_on_hand", with: "9"
    page.should have_selector "span[name='on_hand']", text: "9"

    fill_in "variant_price", with: "4.0"
    fill_in "variant_on_hand", with: "10"
    fill_in "variant_unit_value_with_description", with: "4000 (12x250 mL bottles)"

    page.should have_selector "span[name='on_hand']", text: "10"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    visit '/admin/products/bulk_edit'
    page.should have_selector "a.view-variants"
    first("a.view-variants").trigger('click')

    page.should have_field "variant_price", with: "4.0"
    page.should have_field "variant_on_hand", with: "10"
    page.should have_field "variant_unit_value_with_description", with: "4000 (12x250 mL bottles)"
  end

  scenario "updating delegated attributes of variants in isolation" do
    p = FactoryGirl.create(:product)
    v = FactoryGirl.create(:variant, product: p, price: 3.0)

    login_to_admin_section

    visit '/admin/products/bulk_edit'
    page.should have_selector "a.view-variants"
    first("a.view-variants").trigger('click')

    page.should have_field "variant_price", with: "3.0"

    fill_in "variant_price", with: "10.0"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    visit '/admin/products/bulk_edit'
    page.should have_selector "a.view-variants"
    first("a.view-variants").trigger('click')

    page.should have_field "variant_price", with: "10.0"
  end

  scenario "updating a product mutiple times without refresh" do
    p = FactoryGirl.create(:product, name: 'original name')
    login_to_admin_section

    visit '/admin/products/bulk_edit'

    page.should have_field "product_name", with: "original name"

    fill_in "product_name", with: "new name 1"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    fill_in "product_name", with: "new name 2"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"

    fill_in "product_name", with: "original name"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"
  end

  scenario "updating a product after cloning a product" do
    FactoryGirl.create(:product, :name => "product 1")
    login_to_admin_section

    visit '/admin/products/bulk_edit'

    first("a.clone-product").click

    fill_in "product_name", :with => "new product name"

    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"
  end

  scenario "updating when no changes have been made" do
    Capybara.using_wait_time(2) do
      FactoryGirl.create(:product, :name => "product 1")
      FactoryGirl.create(:product, :name => "product 2")
      login_to_admin_section

      visit '/admin/products/bulk_edit'

      click_button 'Update'
      page.find("span#update-status-message").should have_content "No changes to update."
    end
  end

  scenario "updating when a filter has been applied" do
    p1 = FactoryGirl.create(:simple_product, :name => "product1")
    p2 = FactoryGirl.create(:simple_product, :name => "product2")
    login_to_admin_section

    visit '/admin/products/bulk_edit'

    page.should have_selector "div.option_tab_titles h6", :text => "Filter Products"
    first("div.option_tab_titles h6", :text => "Filter Products").click

    select2_select "Name", from: "filter_property"
    select2_select "Contains", from: "filter_predicate"
    fill_in "filter_value", :with => "1"
    click_button "Apply Filter"
    page.should_not have_field "product_name", with: p2.name
    fill_in "product_name", :with => "new product1"

    click_on 'Update'
    page.find("span#update-status-message").should have_content "Update complete"
  end

  scenario "updating a product when there are more products than the default API page size" do
    26.times { FactoryGirl.create(:simple_product) }
    login_to_admin_section

    visit '/admin/products/bulk_edit'

    field = page.all("table#listing_products input[name='product_name']").first
    field.set "new name"
    click_button 'Update'
    page.find("span#update-status-message").should have_content "Update complete"
  end

  describe "using action buttons" do
    describe "using delete buttons" do
      it "shows a delete button for products, which deletes the appropriate product when clicked" do
        p1 = FactoryGirl.create(:product)
        p2 = FactoryGirl.create(:product)
        p3 = FactoryGirl.create(:product)
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        page.should have_selector "a.delete-product", :count => 3

        first("a.delete-product").click

        page.should have_selector "a.delete-product", :count => 2

        visit '/admin/products/bulk_edit'

        page.should have_selector "a.delete-product", :count => 2
      end

      it "shows a delete button for variants, which deletes the appropriate variant when clicked" do
        v1 = FactoryGirl.create(:variant)
        v2 = FactoryGirl.create(:variant)
        v3 = FactoryGirl.create(:variant)
        login_to_admin_section

        visit '/admin/products/bulk_edit'
        page.should have_selector "a.view-variants"
        all("a.view-variants").each { |e| e.trigger('click') }

        page.should have_selector "a.delete-variant", :count => 3

        first("a.delete-variant").click
        
        page.should have_selector "a.delete-variant", :count => 2

        visit '/admin/products/bulk_edit'
        page.should have_selector "a.view-variants"
        all("a.view-variants").select { |e| e.visible? }.each { |e| e.trigger('click') }

        page.should have_selector "a.delete-variant", :count => 2
      end
    end

    describe "using edit buttons" do
      it "shows an edit button for products, which takes the user to the standard edit page for that product" do
        p1 = FactoryGirl.create(:product)
        p2 = FactoryGirl.create(:product)
        p3 = FactoryGirl.create(:product)
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        page.should have_selector "a.edit-product", :count => 3

        first("a.edit-product").click

        URI.parse(current_url).path.should == "/admin/products/#{p1.permalink}/edit"
      end

      it "shows an edit button for variants, which takes the user to the standard edit page for that variant" do
        v1 = FactoryGirl.create(:variant)
        v2 = FactoryGirl.create(:variant)
        v3 = FactoryGirl.create(:variant)
        login_to_admin_section

        visit '/admin/products/bulk_edit'
        page.should have_selector "a.view-variants"
        all("a.view-variants").each { |e| e.trigger('click') }

        page.should have_selector "a.edit-variant", :count => 3

        first("a.edit-variant").click

        URI.parse(current_url).path.should == "/admin/products/#{v1.product.permalink}/variants/#{v1.id}/edit"
      end
    end

    describe "using clone buttons" do
      it "shows a clone button for products, which duplicates the product and adds it to the page when clicked" do
        p1 = FactoryGirl.create(:product, :name => "P1")
        p2 = FactoryGirl.create(:product, :name => "P2")
        p3 = FactoryGirl.create(:product, :name => "P3")
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        page.should have_selector "a.clone-product", :count => 3

        first("a.clone-product").click
        page.should have_selector "a.clone-product", :count => 4
        page.should have_field "product_name", with: "COPY OF #{p1.name}"
        page.should have_select "supplier", selected: "#{p1.supplier.name}"

        visit '/admin/products/bulk_edit'

        page.should have_selector "a.clone-product", :count => 4
        page.should have_field "product_name", with: "COPY OF #{p1.name}"
        page.should have_select "supplier", selected: "#{p1.supplier.name}"
      end
    end
  end

  describe "using the page" do
    describe "using tabs to hide and display page controls" do
      it "shows a column display toggle button, which shows a list of columns when clicked" do
        FactoryGirl.create(:simple_product)
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        page.should have_selector "div.column_toggle", :visible => false

        page.should have_selector "div.option_tab_titles h6.unselected", :text => "Toggle Columns"
        first("div.option_tab_titles h6", :text => "Toggle Columns").click

        page.should have_selector "div.option_tab_titles h6.selected", :text => "Toggle Columns"
        page.should have_selector "div.column_toggle", :visible => true
        page.should have_selector "li.column-list-item", text: "Available On"

        page.should have_selector "div.filters", :visible => false

        page.should have_selector "div.option_tab_titles h6.unselected", :text => "Filter Products"
        first("div.option_tab_titles h6", :text => "Filter Products").click

        page.should have_selector "div.option_tab_titles h6.unselected", :text => "Toggle Columns"
        page.should have_selector "div.option_tab_titles h6.selected", :text => "Filter Products"
        page.should have_selector "div.filters", :visible => true

        first("div.option_tab_titles h6", :text => "Filter Products").click

        page.should have_selector "div.option_tab_titles h6.unselected", :text => "Filter Products"
        page.should have_selector "div.option_tab_titles h6.unselected", :text => "Toggle Columns"
        page.should have_selector "div.filters", :visible => false
        page.should have_selector "div.column_toggle", :visible => false
      end
    end

    describe "using column display toggle" do
      it "shows a column display toggle button, which shows a list of columns when clicked" do
        FactoryGirl.create(:simple_product)
        login_to_admin_section

        visit '/admin/products/bulk_edit'
        
        first("div.option_tab_titles h6", :text => "Toggle Columns").click
        first("li.column-list-item", text: "Available On").click

        page.should have_selector "th", :text => "NAME"
        page.should have_selector "th", :text => "SUPPLIER"
        page.should have_selector "th", :text => "PRICE"
        page.should have_selector "th", :text => "ON HAND"
        page.should have_selector "th", :text => "AV. ON"

        page.should have_selector "div.option_tab_titles h6", :text => "Toggle Columns"

        page.should have_selector "div ul.column-list li.column-list-item", text: "Supplier"
        first("li.column-list-item", text: "Supplier").click

        page.should_not have_selector "th", :text => "SUPPLIER"
        page.should have_selector "th", :text => "NAME"
        page.should have_selector "th", :text => "PRICE"
        page.should have_selector "th", :text => "ON HAND"
        page.should have_selector "th", :text => "AV. ON"
      end
    end

    describe "using pagination controls" do
      it "shows pagination controls" do
        27.times { FactoryGirl.create(:product) }
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        page.should have_select 'perPage', :selected => '25'
        within '.pagination' do
          page.should have_text "1 2"
          page.should have_text "Next"
          page.should have_text "Last"
        end
      end

      it "allows the number of visible products to be altered" do
        27.times { FactoryGirl.create(:product) }
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        select '25', :from => 'perPage'
        page.all("input[name='product_name']").select{ |e| e.visible? }.length.should == 25
        select '50', :from => 'perPage'
        page.all("input[name='product_name']").select{ |e| e.visible? }.length.should == 27
      end

      it "displays the correct products when changing pages" do
        25.times { FactoryGirl.create(:product, :name => "page1product") }
        5.times { FactoryGirl.create(:product, :name => "page2product") }
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        select '25', :from => 'perPage'
        page.all("input[name='product_name']").select{ |e| e.visible? }.all?{ |e| e.value == "page1product" }.should == true
        find("a", text: "2").click
        page.all("input[name='product_name']").select{ |e| e.visible? }.all?{ |e| e.value == "page2product" }.should == true
      end

      it "moves the user to the last available page when changing the number of pages in any way causes user to become orphaned" do
        50.times { FactoryGirl.create(:product) }
        FactoryGirl.create(:product, :name => "fancy_product_name")
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        select '25', :from => 'perPage'
        find("a", text: "3").click
        select '50', :from => 'perPage'
        page.first("div.pagenav span.page.current").should have_text "2"
        page.all("input[name='product_name']", :visible => true).length.should == 1

        select '25', :from => 'perPage'
        fill_in "quick_filter", :with => "fancy_product_name"
        page.first("div.pagenav span.page.current").should have_text "1"
        page.all("input[name='product_name']", :visible => true).length.should == 1
      end

      it "paginates the filtered product list rather than all products" do
        25.times { FactoryGirl.create(:product, :name => "product_name") }
        3.times { FactoryGirl.create(:product, :name => "test_product_name") }
        login_to_admin_section

        visit '/admin/products/bulk_edit'

        select '25', :from => 'perPage'
        page.should have_text "1 2"
        fill_in "quick_filter", :with => "test_product_name"
        page.all("input[name='product_name']", :visible => true).length.should == 3
        page.all("input[name='product_name']", :visible => true).all?{ |e| e.value == "test_product_name" }.should == true
        page.should_not have_text "1 2"
        page.should have_text "1"
      end
    end

    describe "using filtering controls" do
      it "displays basic filtering controls" do
        FactoryGirl.create(:simple_product)

        login_to_admin_section
        visit '/admin/products/bulk_edit'

        page.should have_selector "div.option_tab_titles h6", :text => "Filter Products"
        first("div.option_tab_titles h6", :text => "Filter Products").click

        page.should have_select "filter_property", visible: false
        page.should have_select "filter_predicate", visible: false
        page.should have_field "filter_value"
      end

      describe "clicking the 'Apply Filter' Button" do
        before(:each) do
          FactoryGirl.create(:simple_product, :name => "Product1")
          FactoryGirl.create(:simple_product, :name => "Product2")

          login_to_admin_section
          visit '/admin/products/bulk_edit'

          first("div.option_tab_titles h6", :text => "Filter Products").click

          select2_select "Name", :from => "filter_property"
          select2_select "Equals", :from => "filter_predicate"
          fill_in "filter_value", :with => "Product1"
          click_button "Apply Filter"
        end

        it "adds a new filter to the list of applied filters" do
          page.should have_text "Name Equals Product1"
        end

        it "displays the 'loading' splash" do
          page.should have_selector "div.loading", :text => "Loading Products..."
        end

        it "loads appropriate products" do
          page.should have_field "product_name", :with => "Product1"
          page.should_not have_field "product_name", :with => "Product2"
        end

        describe "clicking the 'Remove Filter' link" do
          before(:each) do
            find("a", text: "Remove Filter").click
          end

          it "removes the filter from the list of applied filters" do
            page.should_not have_text "Name Equals Product1"
          end

          it "loads appropriate products" do
            page.should have_field "product_name", :with => "Product1"
            page.should have_field "product_name", :with => "Product2"
          end
        end
      end
    end
  end

  context "as an enterprise manager" do
    let(:s1) { create(:supplier_enterprise, name: 'First Supplier') }
    let(:s2) { create(:supplier_enterprise, name: 'Another Supplier') }
    let(:s3) { create(:supplier_enterprise, name: 'Yet Another Supplier') }
    let(:d1) { create(:distributor_enterprise, name: 'First Distributor') }
    let(:d2) { create(:distributor_enterprise, name: 'Another Distributor') }
    let!(:product_supplied) { create(:product, supplier: s1, price: 10.0, on_hand: 6) }
    let!(:product_not_supplied) { create(:product, supplier: s3) }
    let(:product_supplied_inactive) { create(:product, supplier: s1, price: 10.0, on_hand: 6, available_on: 1.week.from_now) }

    before(:each) do
      @enterprise_user = create_enterprise_user
      @enterprise_user.enterprise_roles.build(enterprise: s1).save
      @enterprise_user.enterprise_roles.build(enterprise: s2).save
      @enterprise_user.enterprise_roles.build(enterprise: d1).save

      login_to_admin_as @enterprise_user
    end

    it "shows only products that I supply" do
      visit '/admin/products/bulk_edit'

      page.should have_field 'product_name', with: product_supplied.name
      page.should_not have_field 'product_name', with: product_not_supplied.name
    end

    it "shows only suppliers that I manage" do
      visit '/admin/products/bulk_edit'

      page.should have_select 'supplier', with_options: [s1.name, s2.name], selected: s1.name
      page.should_not have_select 'supplier', with_options: [s3.name]
    end

    it "shows inactive products that I supply" do
      product_supplied_inactive

      visit '/admin/products/bulk_edit'

      page.should have_field 'product_name', with: product_supplied_inactive.name
    end

    it "allows me to update a product" do
      p = product_supplied

      visit '/admin/products/bulk_edit'
      first("div.option_tab_titles h6", :text => "Toggle Columns").click
      first("li.column-list-item", text: "Available On").click

      page.should have_field "product_name", with: p.name
      page.should have_select "supplier", selected: s1.name
      page.should have_field "available_on", with: p.available_on.strftime("%F %T")
      page.should have_field "price", with: "10.0"
      page.should have_field "on_hand", with: "6"

      fill_in "product_name", with: "Big Bag Of Potatoes"
      select s2.name, from: 'supplier'
      fill_in "available_on", with: (Date.today-3).strftime("%F %T")
      fill_in "price", with: "20"
      fill_in "on_hand", with: "18"

      click_button 'Update'
      page.find("span#update-status-message").should have_content "Update complete"

      visit '/admin/products/bulk_edit'
      first("div.option_tab_titles h6", :text => "Toggle Columns").click
      first("li.column-list-item", text: "Available On").click

      page.should have_field "product_name", with: "Big Bag Of Potatoes"
      page.should have_select "supplier", selected: s2.name
      page.should have_field "available_on", with: (Date.today-3).strftime("%F %T")
      page.should have_field "price", with: "20.0"
      page.should have_field "on_hand", with: "18"
    end
  end
end
