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

  context "xóa đơn vị có pump_allocation ở kỳ 6" do
    # Unit model giờ có before_discard :delete_current_period_pump_allocations
    # tương tự ContactPoint — cleanup allocation kỳ đang mở.
    let(:unit_b) { sample.unit_b }

    # Kỳ 6 chạy theo cơ chế per-trạm (TN2) → allocation phải gắn trạm bơm.
    # Trạm bơm 1 (water_pump trong cùng khu vực) là trạm hợp lệ.
    let(:station) { sample.contact_points[:tram_bom_1] }

    before do
      # Tạo allocation cho unit_b (find_or_create vì PeriodService có thể đã copy).
      # Kỳ 5 còn legacy (zone-wide) nên allocation không gắn trạm.
      @alloc_p5 = PumpAllocation.find_or_create_by!(zone: sample.zone, period: period_5, unit: unit_b) do |a|
        a.coefficient = 1
      end
      # Kỳ 6 per-trạm → bắt buộc pump_contact_point (trạm bơm cùng khu vực).
      @alloc_p6 = PumpAllocation.find_or_create_by!(zone: sample.zone, period: period_6, unit: unit_b,
                                                    pump_contact_point: station) do |a|
        a.coefficient = 1
      end
      # Xóa hết CPs + users để unit discard được
      unit_b.contact_points.kept.each(&:discard)
      unit_b.users.destroy_all
      unit_b.discard
    end

    it "PumpAllocation kỳ 5: vẫn tồn tại (data kỳ cũ giữ nguyên)" do
      expect(PumpAllocation.find_by(id: @alloc_p5.id)).to be_present
    end

    it "PumpAllocation kỳ 6: bị xóa (cleanup khi discard)" do
      expect(PumpAllocation.find_by(id: @alloc_p6.id)).to be_nil
    end

    it "pump_allocations index không filter .kept — hiện allocation kỳ cũ nếu xem kỳ đó" do
      # Allocation kỳ 5 vẫn tồn tại trong DB với unit_id trỏ tới unit đã discard.
      # Index query không dùng .kept filter nên sẽ hiện nếu scope đúng kỳ.
      scope = PumpAllocation.where(period: period_5)
                            .joins(:zone)
                            .left_joins(:unit, :contact_point)
      expect(scope.where(unit_id: unit_b.id).count).to eq(1)
    end
  end

end
