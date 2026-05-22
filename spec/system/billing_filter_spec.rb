require "rails_helper"

RSpec.describe "Billing", type: :system do
  let!(:sample) { setup_zone_one_full_sample }
  let!(:zone2) { create(:zone, name: "Khu vực 2") }
  let!(:unit_c) { create(:unit, name: "Đơn vị C", zone: zone2) }
  let!(:cp_zone2) do
    rank = sample.period.ranks.first
    create(:contact_point, :residential, name: "Đầu mối Z2", unit: unit_c,
           initial_personnel_counts: { rank.id => 1 })
  end

  let(:system_admin) { create(:user, :system_admin) }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    sign_in system_admin
  end

  # --- Shared filter behavior ---
  let(:path) { billing_path }
  let(:zone1) { sample.zone }
  let(:unit1) { sample.unit_a }
  let(:unit2) { unit_c }
  let(:content_zone1) { sample.unit_a.name }
  let(:content_zone2) { unit_c.name }
  def path_with_params(**params) = billing_path(**params)

  it_behaves_like "zone-unit cascade filter behavior"

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

  it "KHÔNG thấy dropdown khu vực/đơn vị khi non-SA" do
    unit_admin = create(:user, :unit_admin, unit: sample.unit_a)
    sign_in unit_admin
    visit billing_path
    expect(page).not_to have_select("zone_id")
    expect(page).not_to have_select("unit_id")
  end

  it "kỳ đang mở → hiển thị nút Tính toán lại" do
    visit billing_path
    expect(page).to have_button("Tính toán lại")
  end

  it "kỳ đã đóng → ẩn nút Tính toán lại" do
    sample.period.update!(closed: true)
    new_period = PeriodService.new
                              .open_new_period(year: 2026, month: 6,
                                               unit_price: BigDecimal("2336.4")).period
    visit billing_path(period_id: sample.period.id)
    expect(page).not_to have_button("Tính toán lại")
  end

  it "hiển thị link Xuất Excel" do
    visit billing_path
    expect(page).to have_link("Xuất Excel")
  end
end
