require "rails_helper"

# F01 — Đầu mối (contact_points) CRUD + scope isolation by role.
RSpec.describe "F01 — Contact points", type: :system do
  let(:scenario)   { setup_basic_scenario }
  let(:other_unit) { create(:organization, :unit, parent: scenario.division) }

  # ---------------------------------------------------------------------------
  # admin_unit — full CRUD within their own unit
  # ---------------------------------------------------------------------------
  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "creates, edits, and destroys a contact point" do
      visit contact_points_path

      expect(page).to have_content(I18n.t("contact_points.index.title"))
      expect(page).to have_css("table")

      # Create
      click_on I18n.t("contact_points.index.new_button")
      fill_in I18n.t("contact_points.form.name"), with: "Test Đầu Mối"
      fill_in I18n.t("contact_points.form.group_name"), with: "Ban Tham Mưu"
      click_on I18n.t("contact_points.form.submit_create")

      expect(page).to have_content(I18n.t("flash.contact_points.created"))
      expect(page).to have_content("Test Đầu Mối")

      # Edit
      cp = ContactPoint.find_by!(name: "Test Đầu Mối")
      visit edit_contact_point_path(cp)
      fill_in I18n.t("contact_points.form.name"), with: "Đầu Mối Đã Sửa"
      click_on I18n.t("contact_points.form.submit_update")

      expect(page).to have_content(I18n.t("flash.contact_points.updated"))
      expect(page).to have_content("Đầu Mối Đã Sửa")

      # Destroy — click_button (not click_on) avoids matching the "Xóa bộ lọc" link
      click_button I18n.t("contact_points.actions.delete")
      expect(page).to have_content(I18n.t("flash.contact_points.destroyed"))
      expect(page).not_to have_content("Đầu Mối Đã Sửa")
    end

    it "shows a validation error when name is blank" do
      visit new_contact_point_path
      click_on I18n.t("contact_points.form.submit_create")

      # Form re-renders with an error (blank message from errors.messages.blank)
      expect(page).to have_content(I18n.t("contact_points.new.title"))
      expect(page).to have_content(I18n.t("errors.messages.blank"))
    end

    it "does not list contact points from another unit" do
      own = create(:contact_point, organization: scenario.unit, name: "Own CP")
      foreign = create(:contact_point, organization: other_unit, name: "Foreign CP")

      visit contact_points_path
      expect(page).to have_content(own.name)
      expect(page).not_to have_content(foreign.name)
    end

    it "cannot edit a contact point belonging to another unit (direct URL)" do
      foreign = create(:contact_point, organization: other_unit)
      visit edit_contact_point_path(foreign)

      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  # ---------------------------------------------------------------------------
  # admin_level1 — sees all units + has an organization filter
  # ---------------------------------------------------------------------------
  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "sees contact points across every unit with an organization filter" do
      create(:contact_point, organization: scenario.unit, name: "CP Unit 1")
      create(:contact_point, organization: other_unit, name: "CP Unit 2")

      visit contact_points_path

      expect(page).to have_content("CP Unit 1")
      expect(page).to have_content("CP Unit 2")
      expect(page).to have_css("select[name='q[organization_id_eq]']")
    end
  end

  # ---------------------------------------------------------------------------
  # commander — read-only
  # ---------------------------------------------------------------------------
  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "sees the list but not the create/edit/delete affordances" do
      create(:contact_point, organization: scenario.unit, name: "CP Read Only")

      visit contact_points_path
      expect(page).to have_content("CP Read Only")
      expect(page).not_to have_link(I18n.t("contact_points.index.new_button"))
      expect(page).not_to have_link(I18n.t("contact_points.actions.edit"))
      expect(page).not_to have_button(I18n.t("contact_points.actions.delete"))
    end

    it "is denied when hitting the new contact point URL directly" do
      visit new_contact_point_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  # ---------------------------------------------------------------------------
  # tech — no business pages at all; bounced to /users
  # ---------------------------------------------------------------------------
  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "is redirected to users_path when trying to view contact points" do
      visit contact_points_path
      expect(page).to have_current_path(users_path)
    end
  end
end
