require "rails_helper"

# End-to-end smoke for ImportFeb2026Service + bảng 24 cột render.
# The service parses test/fixtures/files/bang_tinh_thang_02.xlsx (~5-10s per
# run). We accept that cost here — these are the only specs that exercise the
# real demo data, and they're what catches regressions between the importer and
# the engine (see docs/BANG_22_COT_ANALYSIS.md).
RSpec.describe "ImportFeb2026Service + 24-column render", type: :system do
  let!(:division) { create(:organization, :division, name: "Sư đoàn") }
  let!(:sdb)      { create(:organization, :unit, parent: division, code: "SDB", name: "Sư đoàn bộ") }
  let!(:admin)    { create(:user, :admin_level1, organization: division) }

  before do
    (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
    @result = ImportFeb2026Service.new.call
  end

  it "imports 79 contact points for SDB" do
    expect(@result.contact_points_count).to eq(79)
  end

  it "renders 79 rows in the 24-column monthly summary for admin_level1" do
    login_as admin, scope: :user
    visit monthly_summary_path(period_id: @result.period.id, org_id: sdb.id)

    # 79 contact point rows in tbody + the group/column headers + tfoot total
    expect(page).to have_content(I18n.t("monthly_summary.total_row"))
    # Count contact points actually rendered (rows inside tbody, one per CP).
    # A spot-check is enough — the engine spec separately verifies structure.
    row_count = all("tbody tr").size
    expect(row_count).to eq(79)
  end

  it "shows TMP Trường with total_standard_kw ≈ 579.45 kW" do
    login_as admin, scope: :user
    visit monthly_summary_path(period_id: @result.period.id, org_id: sdb.id)

    tmp_truong = ContactPoint.find_by!(name: "TMP Trường")
    within("tbody tr", text: tmp_truong.name) do
      # vi-VN number_with_precision outputs "579.45" (locale en fallback for
      # the delimiter). The UI currently renders "579.45" — match either form
      # to avoid a brittle locale coupling.
      expect(page).to have_content(/579[.,]45/)
    end

    calc = MonthlyCalculation.find_by!(contact_point: tmp_truong, monthly_period: @result.period)
    expect(calc.total_standard_kw.to_f).to be_within(0.01).of(579.45)
  end
end
