require "rails_helper"

# Cross-cutting authorization — the 4-role × URL matrix. Individual feature
# specs cover their own positive cases; this spec concentrates on the negative
# cases (what each role is *not* allowed to do).
RSpec.describe "Authorization cross-cutting", type: :system do
  let(:scenario)   { setup_basic_scenario }
  let(:other_unit) { create(:organization, :unit, parent: scenario.division) }

  # ---------------------------------------------------------------------------
  # tech — every non-/users URL bounces to /users, without a "Access denied" flash
  # ---------------------------------------------------------------------------
  describe "tech role" do
    before { login_as scenario.tech, scope: :user }

    {
      "contact_points"   => -> { contact_points_path },
      "unit_config"      => -> { unit_config_path },
      "electricity_supply" => -> { electricity_supply_path },
      "meter_readings"   => -> { meter_readings_path },
      "personnel_review" => -> { personnel_review_path },
      "monthly_summary"  => -> { monthly_summary_path }
    }.each do |name, path_proc|
      it "redirects to users_path when visiting #{name}" do
        visit instance_exec(&path_proc)
        expect(page).to have_current_path(users_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # admin_unit — denied when the record belongs to another unit
  # ---------------------------------------------------------------------------
  describe "admin_unit scope isolation" do
    before { login_as scenario.admin_unit, scope: :user }

    it "is denied when editing a contact point from another unit" do
      foreign = create(:contact_point, organization: other_unit)
      visit edit_contact_point_path(foreign)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end

    it "is denied when listing meters under a foreign contact point" do
      foreign = create(:contact_point, organization: other_unit)
      visit contact_point_meters_path(foreign)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end

    it "is denied when opening personnel for a foreign contact point" do
      foreign = create(:contact_point, organization: other_unit)
      visit contact_point_personnel_path(foreign)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  # ---------------------------------------------------------------------------
  # /users — admin_level1 and tech manage users; admin_unit and commander are
  # not part of the user-management flow and should be denied.
  # ---------------------------------------------------------------------------
  describe "/users access" do
    %i[admin_unit commander].each do |role|
      it "denies #{role} access to users_path" do
        login_as scenario.public_send(role), scope: :user
        visit users_path
        expect(page).to have_current_path(root_path)
        expect(page).to have_content(I18n.t("flash.access_denied"))
      end
    end

    it "lets admin_level1 in (manages all resources including User)" do
      login_as scenario.admin_level1, scope: :user
      visit users_path
      expect(page).to have_current_path(users_path)
      expect(page).to have_content(I18n.t("users.index.title"))
    end
  end
end
