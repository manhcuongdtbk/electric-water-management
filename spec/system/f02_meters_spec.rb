require "rails_helper"

# F02 — Công tơ (meters) nested under contact_points, CRUD + meter types.
RSpec.describe "F02 — Meters", type: :system do
  let(:scenario)   { setup_basic_scenario }
  let(:other_unit) { create(:organization, :unit, parent: scenario.division) }
  let(:own_cp)     { create(:contact_point, organization: scenario.unit) }

  # ---------------------------------------------------------------------------
  # admin_unit — full CRUD + all three meter types
  # ---------------------------------------------------------------------------
  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "creates meters of every type (normal, public, pump_station)" do
      visit contact_point_meters_path(own_cp)
      expect(page).to have_content(I18n.t("meters.index.title"))

      # normal
      click_on I18n.t("meters.index.new_button")
      fill_in I18n.t("meters.form.name"), with: "Công tơ thường"
      select I18n.t("meters.meter_types.normal"), from: I18n.t("meters.form.meter_type")
      click_on I18n.t("meters.form.submit_create")
      expect(page).to have_content(I18n.t("flash.meters.created"))

      # public
      click_on I18n.t("meters.index.new_button")
      fill_in I18n.t("meters.form.name"), with: "Công tơ công cộng"
      select I18n.t("meters.meter_types.public_meter"), from: I18n.t("meters.form.meter_type")
      click_on I18n.t("meters.form.submit_create")
      expect(page).to have_content("Công tơ công cộng")
      expect(page).to have_content(I18n.t("meters.meter_types.public_meter"))

      # pump_station
      click_on I18n.t("meters.index.new_button")
      fill_in I18n.t("meters.form.name"), with: "Công tơ trạm bơm"
      select I18n.t("meters.meter_types.pump_station"), from: I18n.t("meters.form.meter_type")
      click_on I18n.t("meters.form.submit_create")
      expect(page).to have_content("Công tơ trạm bơm")
      expect(page).to have_content(I18n.t("meters.meter_types.pump_station"))
    end

    it "edits an existing meter" do
      meter = create(:meter, :normal, contact_point: own_cp, organization: scenario.unit, name: "Trước Sửa")

      visit contact_point_meters_path(own_cp)
      click_on I18n.t("meters.actions.edit")
      fill_in I18n.t("meters.form.name"), with: "Sau Sửa"
      click_on I18n.t("meters.form.submit_update")

      expect(page).to have_content(I18n.t("flash.meters.updated"))
      expect(page).to have_content("Sau Sửa")
      expect(meter.reload.name).to eq("Sau Sửa")
    end

    it "destroys a meter" do
      create(:meter, :normal, contact_point: own_cp, organization: scenario.unit, name: "Sắp xóa")

      visit contact_point_meters_path(own_cp)
      click_button I18n.t("meters.actions.delete")

      expect(page).to have_content(I18n.t("flash.meters.destroyed"))
      expect(page).not_to have_content("Sắp xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # Scope isolation — cannot reach another unit's meters via URL guessing
  # ---------------------------------------------------------------------------
  describe "scope isolation" do
    let(:foreign_cp) { create(:contact_point, organization: other_unit) }

    it "redirects admin_unit away when the parent contact point belongs to another unit" do
      login_as scenario.admin_unit, scope: :user
      visit contact_point_meters_path(foreign_cp)

      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end

    it "redirects admin_unit away when trying to create a meter under a foreign contact point" do
      login_as scenario.admin_unit, scope: :user
      visit new_contact_point_meter_path(foreign_cp)

      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  # ---------------------------------------------------------------------------
  # tech — bounced to /users
  # ---------------------------------------------------------------------------
  describe "tech" do
    it "is redirected to users_path from the meters index" do
      login_as scenario.tech, scope: :user
      visit contact_point_meters_path(own_cp)

      expect(page).to have_current_path(users_path)
    end
  end
end
