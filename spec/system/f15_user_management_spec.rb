require "rails_helper"

# F15 — Quản lý tài khoản (users CRUD + lock/unlock + last-admin guard).
# Only admin_level1 and tech can manage users (see ability.rb).
RSpec.describe "F15 — User management", type: :system do
  let(:scenario) { setup_basic_scenario }

  # ---------------------------------------------------------------------------
  # admin_level1 CRUD
  # ---------------------------------------------------------------------------
  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "lists every user in the system" do
      scenario # force creation of the 4 role users
      visit users_path
      expect(page).to have_content(I18n.t("users.index.title"))
      expect(page).to have_content(scenario.admin_unit.email)
      expect(page).to have_content(scenario.commander.email)
      expect(page).to have_content(scenario.tech.email)
    end

    it "creates a new admin_unit account tied to an organization" do
      visit new_user_path

      fill_in I18n.t("users.form.full_name"), with: "Nguyễn Văn Mới"
      fill_in I18n.t("users.form.email"), with: "newadmin@example.com"
      fill_in I18n.t("users.form.password"), with: "StrongPass1!"
      fill_in I18n.t("users.form.password_confirmation"), with: "StrongPass1!"
      select I18n.t("users.roles.admin_unit"), from: I18n.t("users.form.role")
      select scenario.unit.name, from: I18n.t("users.form.organization")
      click_on I18n.t("users.form.submit_create")

      expect(page).to have_content(I18n.t("flash.users.created"))
      new_user = User.find_by!(email: "newadmin@example.com")
      expect(new_user.role).to eq("admin_unit")
      expect(new_user.organization).to eq(scenario.unit)
    end

    it "changes an existing user's role via the edit form" do
      visit edit_user_path(scenario.commander)
      select I18n.t("users.roles.admin_unit"), from: I18n.t("users.form.role")
      click_on I18n.t("users.form.submit_update")

      expect(page).to have_content(I18n.t("flash.users.updated"))
      expect(scenario.commander.reload.role).to eq("admin_unit")
    end

    it "resetting another user's password sets force_password_change = true" do
      target = scenario.admin_unit
      visit edit_user_path(target)
      fill_in I18n.t("users.form.password"), with: "AdminReset1!"
      fill_in I18n.t("users.form.password_confirmation"), with: "AdminReset1!"
      click_on I18n.t("users.form.submit_update")

      expect(page).to have_content(I18n.t("flash.users.updated"))
      expect(target.reload.force_password_change).to be true
    end

    it "locks an active user from the index action row" do
      target = scenario.admin_unit
      visit users_path

      within("tr", text: target.email) do
        click_button I18n.t("users.actions.lock")
      end
      expect(page).to have_content(I18n.t("flash.users.locked"))
      expect(target.reload.access_locked?).to be true
    end

    it "unlocks a locked user from the index action row" do
      target = create(:user, :admin_unit, :locked,
                      organization: scenario.unit, email: "locked@example.com")
      visit users_path

      within("tr", text: target.email) do
        click_button I18n.t("users.actions.unlock")
      end
      expect(page).to have_content(I18n.t("flash.users.unlocked"))
      expect(target.reload.access_locked?).to be false
    end

    it "hides the Lock button on the current user's own row (self-lock UI guard)" do
      visit users_path
      within("tr", text: scenario.admin_level1.email) do
        expect(page).not_to have_button(I18n.t("users.actions.lock"))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Last-active-admin guard — exercised via tech (not self) so the self-lock
  # branch doesn't short-circuit in front of it.
  # ---------------------------------------------------------------------------
  describe "last-active-admin guard" do
    it "refuses to lock the only remaining admin_level1" do
      # scenario has exactly one admin_level1. tech is authorized (:manage, User)
      # but is not the target, so the controller falls through to the
      # last-active-admin check instead of the self-lock check.
      login_as scenario.tech, scope: :user
      page.driver.submit :patch, lock_user_path(scenario.admin_level1), {}

      expect(page).to have_content(I18n.t("flash.users.cannot_lock_last_admin"))
      expect(scenario.admin_level1.reload.access_locked?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # tech — full user management access, same CRUD as admin_level1
  # ---------------------------------------------------------------------------
  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "can open the users index and create a new admin_unit user" do
      visit users_path
      expect(page).to have_content(I18n.t("users.index.title"))

      click_on I18n.t("users.index.new_button")
      fill_in I18n.t("users.form.full_name"), with: "Tech Created"
      fill_in I18n.t("users.form.email"), with: "techcreated@example.com"
      fill_in I18n.t("users.form.password"), with: "Password1!"
      fill_in I18n.t("users.form.password_confirmation"), with: "Password1!"
      select I18n.t("users.roles.admin_unit"), from: I18n.t("users.form.role")
      select scenario.unit.name, from: I18n.t("users.form.organization")
      click_on I18n.t("users.form.submit_create")

      expect(page).to have_content(I18n.t("flash.users.created"))
      expect(User.find_by(email: "techcreated@example.com")).to be_present
    end
  end
end
