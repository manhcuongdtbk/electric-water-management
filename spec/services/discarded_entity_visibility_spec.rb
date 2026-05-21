require "rails_helper"

# Test kịch bản: tạo entity ở kỳ N-1, xóa ở kỳ N, xem data ở kỳ N-1/N/N+1.
# Nghiệp vụ 23.1: "Dữ liệu kỳ cũ giữ nguyên" khi xóa entity.
# Data per kỳ tự lọc — có record = hiện, không có = không hiện.
RSpec.describe "Hiển thị data kỳ cũ cho entity đã xóa" do
  let(:service) { PeriodService.new }
  let(:sample) { setup_zone_one_full_sample }
  let(:period_5) { sample.period }
  let(:system_admin) { create(:user, :system_admin) }

  before do
    # Kỳ 5: tính toán → có calculations cho tất cả CPs
    CalculationOrchestrator.new(zone: sample.zone, period: period_5).call
    # Đóng kỳ 5, mở kỳ 6
    period_5.update!(closed: true)
    @period_6 = service.open_new_period.period
    # Nhập data kỳ 6
    sample.meters.each_value do |m|
      reading = m.meter_readings.find_by(period: @period_6)
      reading&.update!(reading_end: reading.reading_start + 100)
    end
    sample.main_meter.main_meter_readings.create!(period: @period_6, usage: BigDecimal("2000"))
    CalculationOrchestrator.new(zone: sample.zone, period: @period_6).call
  end

  let(:period_6) { @period_6 }

  context "xóa đầu mối ở kỳ 6, xem kỳ 5" do
    let(:kho_vat_tu) { sample.contact_points[:kho_vat_tu] }

    before { kho_vat_tu.discard }

    it "Billing::Query kỳ 5: vẫn thấy đầu mối đã xóa" do
      ability = Ability.new(system_admin)
      scope = Billing::Query.base_scope(period_5, ability)
      cp_ids = scope.pluck(:contact_point_id)
      expect(cp_ids).to include(kho_vat_tu.id)
    end

    it "Billing::Query kỳ 6: KHÔNG thấy đầu mối đã xóa (data kỳ 6 đã cleanup)" do
      ability = Ability.new(system_admin)
      scope = Billing::Query.base_scope(period_6, ability)
      cp_ids = scope.pluck(:contact_point_id)
      expect(cp_ids).not_to include(kho_vat_tu.id)
    end

    it "MeterReading kỳ 5: vẫn có readings cho đầu mối đã xóa" do
      meter = kho_vat_tu.meters.with_discarded.first
      readings = MeterReading.where(period: period_5, meter_id: meter.id)
      expect(readings).to be_present
    end

    it "MeterReading kỳ 6: KHÔNG có readings (cleanup khi discard)" do
      meter = kho_vat_tu.meters.with_discarded.first
      readings = MeterReading.where(period: period_6, meter_id: meter.id)
      expect(readings).to be_empty
    end
  end

  context "xóa đầu mối ở kỳ 6, mở kỳ 7" do
    let(:kho_vat_tu) { sample.contact_points[:kho_vat_tu] }

    before do
      kho_vat_tu.discard
      period_6.update!(closed: true)
      @period_7 = service.open_new_period.period
    end

    let(:period_7) { @period_7 }

    it "Billing::Query kỳ 7: KHÔNG thấy đầu mối đã xóa (không được copy)" do
      CalculationOrchestrator.new(zone: sample.zone, period: period_7).call
      ability = Ability.new(system_admin)
      scope = Billing::Query.base_scope(period_7, ability)
      cp_ids = scope.pluck(:contact_point_id)
      expect(cp_ids).not_to include(kho_vat_tu.id)
    end

    it "Billing::Query kỳ 5: vẫn thấy đầu mối đã xóa" do
      ability = Ability.new(system_admin)
      scope = Billing::Query.base_scope(period_5, ability)
      cp_ids = scope.pluck(:contact_point_id)
      expect(cp_ids).to include(kho_vat_tu.id)
    end
  end

end
