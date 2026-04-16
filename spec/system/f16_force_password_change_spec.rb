require "rails_helper"

# F16 — Force password change on first login
# Covers the full browser flow: login → redirect → change password → free navigation.
RSpec.describe "F16 — Force password change", type: :system do
  let(:division) { create(:organization, :division) }
  let(:unit)     { create(:organization, :unit, parent: division) }
  let(:user)     { create(:user, :admin_unit, organization: unit, force_password_change: true) }

  # -------------------------------------------------------------------------
  # Login form redirect
  # -------------------------------------------------------------------------
  it "redirects to password change page after sign-in when force_password_change is true" do
    visit new_user_session_path

    find('input[name="user[email]"]').set(user.email)
    find('input[name="user[password]"]').set("Password1!")
    find('input[type="submit"]').click

    expect(page).to have_current_path(edit_password_change_path)
    expect(page).to have_content(I18n.t("password_changes.edit.title"))
    expect(page).to have_content(I18n.t("password_changes.edit.subtitle"))
  end

  # -------------------------------------------------------------------------
  # Block other pages
  # -------------------------------------------------------------------------
  it "redirects to password change when accessing any other page" do
    login_as user, scope: :user

    visit contact_points_path
    expect(page).to have_current_path(edit_password_change_path)
    expect(page).to have_content(I18n.t("flash.password_changes.required"))
  end

  # -------------------------------------------------------------------------
  # Successful change → free navigation
  # -------------------------------------------------------------------------
  it "allows full navigation after changing password" do
    login_as user, scope: :user

    visit edit_password_change_path
    fill_in I18n.t("password_changes.form.new_password"),    with: "NewMilitary1!"
    fill_in I18n.t("password_changes.form.confirm_password"), with: "NewMilitary1!"
    click_on I18n.t("password_changes.form.submit")

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(I18n.t("flash.password_changes.success"))

    # Can now navigate to another page without being redirected
    visit contact_points_path
    expect(page).to have_current_path(contact_points_path)
    expect(page).not_to have_content(I18n.t("password_changes.edit.title"))
  end

  # -------------------------------------------------------------------------
  # Validation errors stay on the form
  # -------------------------------------------------------------------------
  it "stays on the form when passwords do not match" do
    login_as user, scope: :user

    visit edit_password_change_path
    fill_in I18n.t("password_changes.form.new_password"),    with: "NewMilitary1!"
    fill_in I18n.t("password_changes.form.confirm_password"), with: "WrongConfirm1!"
    click_on I18n.t("password_changes.form.submit")

    # Error re-renders the form
    expect(page).to have_content(I18n.t("password_changes.edit.title"))
    # force_password_change must still be true (password was NOT saved)
    expect(user.reload.force_password_change).to be true
  end

  # -------------------------------------------------------------------------
  # Tech user with force_password_change = true → password change page,
  # NOT users_path (check_force_password_change! runs before restrict_tech!)
  # -------------------------------------------------------------------------
  it "redirects tech user to password change page, not users_path, when flag is set" do
    tech_user = create(:user, :tech, organization: division, force_password_change: true)
    login_as tech_user, scope: :user

    visit users_path
    expect(page).to have_current_path(edit_password_change_path)
    expect(page).to have_content(I18n.t("password_changes.edit.title"))
  end

  # -------------------------------------------------------------------------
  # Admin edits own password → force_password_change must NOT be set
  # -------------------------------------------------------------------------
  it "does not set force_password_change when admin updates their own password" do
    admin = create(:user, :admin_level1, organization: division, force_password_change: false)
    login_as admin, scope: :user

    visit edit_user_path(admin)
    fill_in I18n.t("users.form.password"),              with: "MyNewPass1!"
    fill_in I18n.t("users.form.password_confirmation"), with: "MyNewPass1!"
    click_on I18n.t("users.form.submit_update")

    expect(page).to have_content(I18n.t("flash.users.updated"))
    expect(admin.reload.force_password_change).to be false
  end

  # -------------------------------------------------------------------------
  # Admin resets password → target user forced on next login
  # -------------------------------------------------------------------------
  it "forces target user to change password after admin resets it" do
    admin = create(:user, :admin_level1, organization: division, force_password_change: false)
    target = create(:user, :admin_unit, organization: unit, force_password_change: false)

    login_as admin, scope: :user

    visit edit_user_path(target)
    fill_in I18n.t("users.form.password"),              with: "AdminReset1!"
    fill_in I18n.t("users.form.password_confirmation"), with: "AdminReset1!"
    click_on I18n.t("users.form.submit_update")

    expect(page).to have_content(I18n.t("flash.users.updated"))
    expect(target.reload.force_password_change).to be true
  end
end
