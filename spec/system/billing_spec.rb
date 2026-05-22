require "rails_helper"

RSpec.describe "Billing", type: :system do
  let(:system_admin) { create(:user, :system_admin) }

  # Billing cần calculation data cho dropdowns → không thể lightweight.
  let!(:sample) { setup_zone_one_full_sample }
  let!(:zone2) { Zone.create!(name: "Khu vực 2", main_meters_attributes: [{ name: "CT-Z2" }]) }
  let!(:unit2) { create(:unit, name: "Đơn vị C", zone: zone2) }
  let!(:cp_zone2) do
    rank = sample.period.ranks.first
    create(:contact_point, :residential, name: "CP Z2", unit: unit2,
           initial_personnel_counts: { rank.id => 1 })
  end

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    create(:calculation, period: sample.period, contact_point: cp_zone2)
    sign_in system_admin
  end

  # --- Shared toolbar behavior ---
  let(:path) { billing_path }
  let(:zone1) { sample.zone }
  let(:unit1) { sample.unit_a }
  let(:filter_select_ids) { %w[zone_id unit_id] }
  def path_with_params(**params) = billing_path(**params)

  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "role-based filter visibility"

  # --- Page-specific ---

  it "đổi kỳ → auto-submit, trang reload đúng kỳ" do
    sample.period.update!(closed: true)
    new_period = PeriodService.new
                              .open_new_period(year: 2026, month: 6,
                                               unit_price: BigDecimal("2336.4")).period
    CalculationOrchestrator.new(zone: sample.zone, period: new_period).call

    visit billing_path
    expect(page).to have_content("Tháng 6/2026")

    select "Tháng #{sample.period.month}/#{sample.period.year}", from: "period_id"
    expect(page).to have_content("Đã đóng")
  end

  it "kỳ đang mở → hiển thị nút Tính toán lại" do
    visit billing_path
    expect(page).to have_button("Tính toán lại")
  end

  it "kỳ đã đóng → ẩn nút Tính toán lại" do
    sample.period.update!(closed: true)
    PeriodService.new.open_new_period(year: 2026, month: 6,
                                      unit_price: BigDecimal("2336.4"))
    visit billing_path(period_id: sample.period.id)
    expect(page).not_to have_button("Tính toán lại")
  end

  it "hiển thị link Xuất Excel" do
    visit billing_path
    expect(page).to have_link("Xuất Excel")
  end
end
