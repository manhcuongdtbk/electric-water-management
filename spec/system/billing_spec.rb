require "rails_helper"

RSpec.describe "Billing", type: :system do
  let(:system_admin) { create(:user, :system_admin) }

  # --- Cascade filter behavior: lightweight setup (không cần full sample/calculations) ---
  context "filter cascade" do
    let!(:period) { create(:period, closed: false) }
    let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
    let!(:zone2) { create(:zone, name: "Khu vực Beta") }
    let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A") }
    let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B") }

    before { sign_in system_admin }

    let(:path) { billing_path }
    let(:zone_blank_text) { "Tất cả" }
    let(:unit_blank_text) { "Tất cả" }
    def path_with_params(**params) = billing_path(**params)

    it_behaves_like "zone-unit cascade filter behavior"
  end

  # --- Page-specific: cần full sample ---
  context "page-specific" do
    let!(:sample) { setup_zone_one_full_sample }

    before { sign_in system_admin }

    it "đổi kỳ → auto-submit, trang reload đúng kỳ" do
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
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
end
