require "rails_helper"

# Request spec: SA xem billing/meter_entries kỳ cũ có entity đã xóa.
RSpec.describe "Hiển thị data kỳ cũ cho entity đã xóa (request)", type: :request do
  let(:service) { PeriodService.new }
  let(:sample) { setup_zone_one_full_sample }
  let(:period_5) { sample.period }
  let(:system_admin) { create(:user, :system_admin) }
  let(:kho_vat_tu) { sample.contact_points[:kho_vat_tu] }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: period_5).call
    period_5.update!(closed: true)
    @period_6 = service.open_new_period.period
    sample.meters.each_value do |m|
      reading = m.meter_readings.find_by(period: @period_6)
      reading&.update!(reading_end: reading.reading_start + 100)
    end
    sample.main_meter.main_meter_readings.create!(period: @period_6, usage: BigDecimal("2000"))
    CalculationOrchestrator.new(zone: sample.zone, period: @period_6).call
    kho_vat_tu.discard
    sign_in system_admin
  end

  let(:period_6) { @period_6 }

  describe "GET /billing" do
    it "kỳ 5 (mở lại): thấy đầu mối đã xóa trong bảng tính tiền" do
      service.close_period(period_6)
      service.reopen_period(period_5)
      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(kho_vat_tu.name)
    end

    it "kỳ 6 (đang mở): KHÔNG thấy đầu mối đã xóa (data cleanup)" do
      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(kho_vat_tu.name)
    end
  end

  describe "GET /meter_entries" do
    it "kỳ 5 (mở lại): thấy readings đầu mối đã xóa" do
      service.close_period(period_6)
      service.reopen_period(period_5)
      get meter_entries_path
      expect(response).to have_http_status(:ok)
      meter_name = kho_vat_tu.meters.with_discarded.first.name
      expect(response.body).to include(meter_name)
    end

    it "kỳ 6 (đang mở): KHÔNG thấy readings đầu mối đã xóa" do
      get meter_entries_path
      expect(response).to have_http_status(:ok)
      meter_name = kho_vat_tu.meters.with_discarded.first.name
      expect(response.body).not_to include(meter_name)
    end
  end

  describe "SA filter dropdown bao gồm zone đã xóa" do
    before do
      # Xóa toàn bộ zone (xóa hết CPs → units → zone)
      sample.contact_points.each_value(&:discard)
      sample.unit_a.users.destroy_all
      sample.unit_b.users.destroy_all
      sample.unit_a.discard
      sample.unit_b.discard
      sample.zone.discard
    end

    it "GET /history kỳ 5: dropdown zone chứa zone đã xóa" do
      get history_path(mode: "single", period_id: period_5.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sample.zone.name)
    end

    it "GET /history kỳ 5: filter theo zone đã xóa → thấy data" do
      get history_path(mode: "single", period_id: period_5.id, zone_id: sample.zone.id)
      expect(response).to have_http_status(:ok)
      # Billing::Query trả calculations cho zone đã xóa ở kỳ 5
      expect(response.body).to include("Ban Tác huấn")
    end
  end

  describe "POST /billing/recalculate kỳ cũ có zone đã xóa" do
    before do
      sample.contact_points.each_value(&:discard)
      sample.unit_a.users.destroy_all
      sample.unit_b.users.destroy_all
      sample.unit_a.discard
      sample.unit_b.discard
      sample.zone.discard
      service.close_period(period_6)
      service.reopen_period(period_5)
    end

    it "recalculate bao gồm zone đã xóa → calculations cập nhật" do
      post recalculate_billing_path
      expect(response).to redirect_to(billing_path)
      # Zone đã xóa vẫn được tính toán vì zones_in_scope dùng with_discarded
      calc = Calculation.find_by(period: period_5, contact_point: sample.contact_points[:ban_tac_huan])
      expect(calc).to be_present
    end
  end
end
