require "rails_helper"

# F07 — Soát lại quân số (personnel_review) — period inheritance, lock/unlock
# visibility, and the edit gate for locked periods.
RSpec.describe "F07 — Period inheritance + lock/unlock", type: :system do
  # NOTE: setup_basic_scenario creates a default period (2026/02). The inheritance
  # flow needs an explicit prior period, so this spec lays out its own dates.
  let(:division)     { create(:organization, :division) }
  let(:unit)         { create(:organization, :unit, parent: division) }
  let(:admin_unit)   { create(:user, :admin_unit,   organization: unit) }
  let(:admin_level1) { create(:user, :admin_level1, organization: division) }
  let(:commander)    { create(:user, :commander,    organization: unit) }
  let(:cp)           { create(:contact_point, organization: unit) }

  before { (1..7).each { |g| create(:rank_quota, :"rank#{g}") } }

  # ---------------------------------------------------------------------------
  # admin_level1 opens a new period → inheritance runs, previous period locks
  # ---------------------------------------------------------------------------
  describe "opening a new period" do
    it "inherits personnel and locks the previous period" do
      jan = create(:monthly_period, year: 2026, month: 1, locked: false)
      create(:personnel,
             contact_point: cp, monthly_period: jan,
             rank1_count: 3, rank2_count: 1, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      login_as admin_level1, scope: :user
      visit personnel_review_path(period_id: jan.id)

      # Open the "Mở kỳ mới" collapsible, then fill + submit
      find("summary", text: I18n.t("personnel_reviews.new_period_form.title")).click
      fill_in I18n.t("personnel_reviews.new_period_form.year_label"), with: "2026"
      fill_in I18n.t("personnel_reviews.new_period_form.month_label"), with: "2"
      click_on I18n.t("personnel_reviews.new_period_form.submit")

      feb = MonthlyPeriod.find_by!(year: 2026, month: 2)
      expect(page).to have_content(I18n.t("flash.monthly_periods.created", label: feb.label))

      # Previous period auto-locked
      expect(jan.reload.locked?).to be true

      # Personnel inherited for cp at feb with identical ranks
      inherited = Personnel.find_by!(contact_point: cp, monthly_period: feb)
      expect(inherited.rank1_count).to eq(3)
      expect(inherited.rank2_count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # admin_level1 can unlock; admin_unit cannot
  # ---------------------------------------------------------------------------
  describe "unlock action" do
    let(:locked_period) { create(:monthly_period, :locked, year: 2026, month: 1, locked_by: admin_level1) }

    it "lets admin_level1 unlock a locked period and then admin_unit can edit personnel" do
      create(:personnel,
             contact_point: cp, monthly_period: locked_period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      login_as admin_level1, scope: :user
      visit personnel_review_path(period_id: locked_period.id)
      expect(page).to have_content(I18n.t("personnel_reviews.lock_banner.locked"))
      click_on I18n.t("personnel_reviews.actions.unlock")
      expect(page).to have_content(
        I18n.t("flash.monthly_periods.unlocked", label: locked_period.label)
      )
      expect(locked_period.reload.locked?).to be false

      # Reset warden, log in as admin_unit, edit personnel
      Warden.test_reset!
      login_as admin_unit, scope: :user
      visit contact_point_personnel_path(cp, period_id: locked_period.id)

      fill_in "personnel_rank1_count", with: 5
      click_on I18n.t("personnel.form.submit")
      expect(page).to have_content(I18n.t("flash.personnel.saved"))
    end

    it "does not show an unlock button to admin_unit on a locked period" do
      create(:personnel,
             contact_point: cp, monthly_period: locked_period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      login_as admin_unit, scope: :user
      visit personnel_review_path(period_id: locked_period.id)

      expect(page).to have_content(I18n.t("personnel_reviews.lock_banner.locked"))
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.unlock"))
      # Toggle/unmark buttons are hidden too because the period is locked
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.toggle_review"))
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.unmark_review"))
    end
  end

  # ---------------------------------------------------------------------------
  # Editing personnel inside a locked period is blocked with a flash
  # ---------------------------------------------------------------------------
  describe "editing personnel in a locked period" do
    it "redirects with a 'period locked' alert when admin_unit tries to save" do
      locked = create(:monthly_period, :locked, year: 2026, month: 1, locked_by: admin_level1)
      create(:personnel,
             contact_point: cp, monthly_period: locked,
             rank1_count: 1, rank2_count: 0, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      login_as admin_unit, scope: :user
      visit contact_point_personnel_path(cp, period_id: locked.id)

      fill_in "personnel_rank1_count", with: 9
      click_on I18n.t("personnel.form.submit")

      expect(page).to have_content(I18n.t("flash.personnel.period_locked"))
      # Value did not persist
      personnel = Personnel.find_by!(contact_point: cp, monthly_period: locked)
      expect(personnel.rank1_count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # commander — lock banner visible, no actions
  # ---------------------------------------------------------------------------
  describe "commander" do
    it "sees the lock banner but no unlock or review buttons" do
      locked = create(:monthly_period, :locked, year: 2026, month: 1, locked_by: admin_level1)
      create(:personnel,
             contact_point: cp, monthly_period: locked,
             rank1_count: 2, rank2_count: 0, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      login_as commander, scope: :user
      visit personnel_review_path(period_id: locked.id)

      expect(page).to have_content(I18n.t("personnel_reviews.lock_banner.locked"))
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.unlock"))
      expect(page).not_to have_link(I18n.t("personnel_reviews.actions.edit"))
    end
  end
end
