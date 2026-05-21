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

  describe "GET /pump_entries kỳ cũ có water_pump đã xóa" do
    let(:pump_cp) { sample.contact_points[:tram_bom_1] }
    let(:pump_meter) { pump_cp.meters.first }

    before { pump_cp.discard }

    it "kỳ 5 (mở lại): thấy readings bơm nước đã xóa" do
      service.close_period(period_6)
      service.reopen_period(period_5)
      get pump_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pump_meter.name)
    end

    it "kỳ 6 (đang mở): KHÔNG thấy readings bơm nước đã xóa" do
      get pump_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(pump_meter.name)
    end
  end

  describe "GET /electricity_supply kỳ cũ có zone đã xóa" do
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

    it "thấy main_meter_reading kỳ 5 cho zone đã xóa" do
      get electricity_supply_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sample.main_meter.name)
    end
  end

  describe "GET /unit_config kỳ cũ có đầu mối đã xóa" do
    before do
      kho_vat_tu.discard
      service.close_period(period_6)
      service.reopen_period(period_5)
    end

    it "thấy other_deductions kỳ 5 cho đầu mối đã xóa" do
      get unit_config_path(unit_id: sample.unit_a.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(kho_vat_tu.name)
    end
  end

  describe "GET /dashboard kỳ cũ có unit đã xóa" do
    before do
      sample.contact_points.values.select { |cp| cp.unit_id == sample.unit_b.id }.each(&:discard)
      sample.unit_b.users.destroy_all
      sample.unit_b.discard
      service.close_period(period_6)
      service.reopen_period(period_5)
    end

    it "tổng quan bao gồm unit đã xóa" do
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sample.unit_b.name)
    end
  end

  describe "UA-ZM xem kỳ cũ có zone-level CP đã xóa" do
    let(:ua_zm) { create(:user, :unit_admin, unit: sample.unit_a) }
    let(:chi_huy_kv) { sample.contact_points[:chi_huy_khu_vuc] }

    before do
      chi_huy_kv.discard
      sign_out system_admin
      sign_in ua_zm
    end

    it "GET /billing kỳ 5: UA-ZM thấy đầu mối sinh hoạt khu vực đã xóa" do
      service.close_period(period_6)
      service.reopen_period(period_5)
      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(chi_huy_kv.name)
    end

    it "GET /billing kỳ 6: KHÔNG thấy đầu mối khu vực đã xóa" do
      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(chi_huy_kv.name)
    end

    it "GET /meter_entries kỳ 5: thấy readings đầu mối khu vực đã xóa" do
      service.close_period(period_6)
      service.reopen_period(period_5)
      get meter_entries_path
      expect(response).to have_http_status(:ok)
      meter_name = chi_huy_kv.meters.with_discarded.first.name
      expect(response.body).to include(meter_name)
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

  describe "Cảnh báo dữ liệu KHÔNG hiện entity đã xóa" do
    it "GET /billing kỳ 6: cảnh báo không nhắc đầu mối đã xóa ở kỳ 5" do
      # Xóa đầu mối ở kỳ 6 (đang mở)
      kho_vat_tu.discard
      get billing_path
      expect(response).to have_http_status(:ok)
      # Cảnh báo không nhắc đến entity đã xóa
      expect(response.body).not_to include("Kho vật tư")
    end

    it "GET /billing kỳ 5 (mở lại): cảnh báo không nhắc đầu mối đã xóa ở kỳ 6" do
      kho_vat_tu.discard
      service.close_period(period_6)
      service.reopen_period(period_5)
      get billing_path
      expect(response).to have_http_status(:ok)
      # Kỳ 5 có data đầy đủ cho Kho vật tư (chưa xóa lúc đó) → không cảnh báo "chưa nhập"
      warnings_section = response.body[/Cảnh báo.*?<\/div>/m] || ""
      expect(warnings_section).not_to include("Kho vật tư")
    end

    it "GET /billing kỳ 6: xóa toàn bộ zone → cảnh báo không nhắc zone đã xóa" do
      sample.contact_points.each_value(&:discard)
      sample.unit_a.users.destroy_all
      sample.unit_b.users.destroy_all
      sample.unit_a.discard
      sample.unit_b.discard
      sample.zone.discard

      get billing_path
      expect(response).to have_http_status(:ok)
      # Zone đã xóa không có data kỳ 6 → ZoneWarningCollector skip
      warnings_section = response.body[/Cảnh báo.*?<\/div>/m] || ""
      expect(warnings_section).not_to include(sample.zone.name)
    end

    it "GET /dashboard kỳ 6: cảnh báo không nhắc entity đã xóa" do
      kho_vat_tu.discard
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Kho vật tư")
    end
  end
end
