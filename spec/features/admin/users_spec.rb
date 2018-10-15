require "spec_helper"

feature "Managing users" do
  include AuthenticationWorkflow

  context "as super-admin" do
    before do
      create(:mail_method)
      quick_login_as_admin
    end

    describe "creating a user" do
      it "shows no confirmation message to start with" do
        visit spree.new_admin_user_path
        expect(page).to have_no_text "Email confirmation is pending"
      end

      it "confirms successful creation" do
        visit spree.new_admin_user_path
        fill_in "Email", with: "user1@example.org"
        fill_in "Password", with: "user1Secret"
        fill_in "Confirm Password", with: "user1Secret"
        expect do
          click_button "Create"
        end.to change { Spree::User.count }.by 1
        expect(page).to have_text "Created Successfully"
        expect(page).to have_text "Email confirmation is pending"
      end
    end

    describe "resending confirmation email", js: true do
      let(:user) { create :user, confirmed_at: nil }

      it "displays success" do
        visit spree.edit_admin_user_path user

        expect do
          # The `a` element doesn't have an href, so we can't use click_link.
          find("a", text: "Resend").click
          expect(page).to have_text "Resend done"
        end.to send_confirmation_instructions
      end
    end
  end
end
