require "rails_helper"

# Tập hợp test case cho nguyên tắc cách ly kỳ.
# Pattern chung: setup 2 kỳ → tính toán → sửa kỳ 2 → tính toán lại → assert kỳ 1 không đổi.
RSpec.describe "Cách ly kỳ giữa các period" do
  let(:service) { PeriodService.new }
  let(:sample) { setup_zone_one_full_sample }

  def calc_for(period, cp)
    Calculation.find_by(period: period, contact_point: cp)
  end

  def snapshot_calculations(period)
    Calculation.where(period: period).order(:contact_point_id).map do |c|
      c.attributes.slice(
        "contact_point_id", "total_personnel", "residential_standard", "water_pump_standard",
        "total_standard", "savings_deduction", "loss_deduction", "division_public_deduction",
        "unit_public_deduction", "other_deduction", "total_deduction", "remaining_standard",
        "residential_usage", "water_pump_usage", "total_usage", "surplus", "deficit",
        "surplus_amount", "deficit_amount"
      )
    end
  end

  shared_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở" do
    let(:period_5) { sample.period }
    let!(:run_initial_calc) {
      CalculationOrchestrator.new(zone: sample.zone, period: period_5).call
    }
    let(:snapshot_period_5_before) { snapshot_calculations(period_5) }

    before do
      snapshot_period_5_before
      period_5.update!(closed: true)
      @period_6 = service.open_new_period.period
    end

    let(:period_6) { @period_6 }
  end

  describe "T05 — Snapshot quân số" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa quân số kỳ 6 không ảnh hưởng kỳ 5" do
      ha_si_quan_p6 = period_6.ranks.find_by(position: 7)
      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      entry = PersonnelEntry.find_by(period: period_6, contact_point: ban_tac_huan, rank: ha_si_quan_p6)
      entry.update!(count: 5)

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      calc_6 = calc_for(period_6, ban_tac_huan)
      expect(calc_6.total_personnel).to eq(7)
      expect(calc_6.residential_standard).to eq_display("340.00")

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T06 — Snapshot cấu hình đơn vị" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa unit_public_rate kỳ 6 không ảnh hưởng kỳ 5" do
      sample.unit_a.unit_configs.find_by(period: period_6).update!(unit_public_rate: BigDecimal("8"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      calc_6 = calc_for(period_6, ban_tac_huan)
      expected_p6 = BigDecimal("8") * calc_6.total_standard / BigDecimal("100")
      expect(calc_6.unit_public_deduction.round(2, BigDecimal::ROUND_HALF_UP))
        .to eq(expected_p6.round(2, BigDecimal::ROUND_HALF_UP))

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T07 — Snapshot định mức cấp bậc" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa quota rank kỳ 6 không ảnh hưởng kỳ 5" do
      ha_si_quan_p6 = period_6.ranks.find_by(position: 7)
      ha_si_quan_p6.update!(quota: BigDecimal("30"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      calc_6 = calc_for(period_6, ban_tac_huan)
      expect(calc_6.residential_standard).to eq_display("310.00")

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T08 — Snapshot đơn giá" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa unit_price kỳ 6 không ảnh hưởng thành tiền kỳ 5" do
      period_6.update!(unit_price: BigDecimal("2500"))
      sample.meters.each_value do |m|
        next if m.meter_readings.find_by(period: period_6).nil?
        m.meter_readings.find_by(period: period_6).update!(reading_end: m.meter_readings.find_by(period: period_6).reading_start + 100)
      end
      sample.main_meter.main_meter_readings.create!(period: period_6, usage: BigDecimal("1000"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T09 — Snapshot savings_rate + division_public_rate" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa rates kỳ 6 không ảnh hưởng kỳ 5" do
      period_6.update!(savings_rate: BigDecimal("7"), division_public_rate: BigDecimal("12"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      calc_6 = calc_for(period_6, ban_tac_huan)
      expected_savings = BigDecimal("7") * calc_6.total_standard / BigDecimal("100")
      expect(calc_6.savings_deduction.round(2, BigDecimal::ROUND_HALF_UP))
        .to eq(expected_savings.round(2, BigDecimal::ROUND_HALF_UP))

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T10 — Snapshot phân bổ bơm nước" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa fixed_percentage kỳ 6 không ảnh hưởng kỳ 5" do
      chi_huy_alloc_p6 = period_6.pump_allocations.find_by(contact_point: sample.contact_points[:chi_huy_khu_vuc])
      chi_huy_alloc_p6.update!(fixed_percentage: BigDecimal("30"))

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
      chi_huy_alloc_p5 = period_5.pump_allocations.find_by(contact_point: sample.contact_points[:chi_huy_khu_vuc])
      expect(chi_huy_alloc_p5.fixed_percentage).to eq(BigDecimal("20"))
    end
  end

  describe "T11 — Snapshot thuộc tính no_loss" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa no_loss của meter_readings kỳ 6 không ảnh hưởng kỳ 5" do
      ct_a3 = sample.meters[:ct_a3]
      ct_a3.meter_readings.find_by(period: period_6).update!(no_loss: false)

      reading_5 = ct_a3.meter_readings.find_by(period: period_5)
      expect(reading_5.no_loss).to be true
      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T12 — Snapshot cột Khác" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa other_deduction kỳ 6 không ảnh hưởng kỳ 5" do
      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      other_p6 = ban_tac_huan.other_deductions.find_by(period: period_6)
      other_p6.update!(other_type: "coefficient", other_value: BigDecimal("10"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      calc_6 = calc_for(period_6, ban_tac_huan)
      expect(calc_6.other_deduction).to eq_display("50.00")

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
      other_p5 = ban_tac_huan.other_deductions.find_by(period: period_5)
      expect(other_p5.other_type).to eq("fixed")
      expect(other_p5.other_value).to eq(BigDecimal("5"))
    end
  end

  describe "T13 — Mở lại kỳ cũ, sửa, đóng lại" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa meter_reading.reading_end kỳ 5 không ảnh hưởng reading_start kỳ 6, cảnh báo khi đóng" do
      ct_a1 = sample.meters[:ct_a1]
      reading_start_p6_before = ct_a1.meter_readings.find_by(period: period_6).reading_start

      service.close_period(period_6)
      service.reopen_period(period_5)

      reading_p5 = ct_a1.meter_readings.find_by(period: period_5)
      reading_p5.update!(reading_end: BigDecimal("1300"))

      reading_start_p6_after = ct_a1.meter_readings.find_by(period: period_6).reading_start
      expect(reading_start_p6_after).to eq(reading_start_p6_before)

      result = service.close_period(period_5)
      expect(result.warnings.first).to include("CT-A1", "1300", "1250")
    end
  end

  describe "T15 — Thêm đầu mối ở kỳ sau" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "đầu mối mới chỉ có data ở kỳ 6, không xuất hiện ở kỳ 5" do
      ha_si_quan_p6 = period_6.ranks.find_by(position: 7)
      lai_xe = create(:contact_point, :residential, name: "Lái xe", unit: sample.unit_a,
                      initial_personnel_counts: { ha_si_quan_p6.id => 2 })
      meter_lx = create(:meter, name: "CT-LX", contact_point: lai_xe, no_loss: false)
      meter_lx.meter_readings.find_by(period: period_6).update!(reading_end: BigDecimal("100"))

      expect(PersonnelEntry.where(period: period_5, contact_point: lai_xe)).to be_empty
      expect(MeterReading.where(period: period_5, meter: meter_lx)).to be_empty
      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T16 — Xóa đầu mối ở kỳ sau" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "đầu mối discarded không tính ở kỳ 6, kỳ 5 vẫn giữ" do
      kho_vat_tu = sample.contact_points[:kho_vat_tu]
      kho_vat_tu.discard

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      expect(calc_for(period_6, kho_vat_tu)).to be_nil
      expect(calc_for(period_5, kho_vat_tu)).to be_present
      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T17 — Snapshot tiêu chuẩn bơm nước" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "sửa water_pump_standard kỳ 6 không ảnh hưởng kỳ 5" do
      period_6.update!(water_pump_standard: BigDecimal("12"))

      CalculationOrchestrator.new(zone: sample.zone, period: period_6).call

      ban_tac_huan = sample.contact_points[:ban_tac_huan]
      calc_6 = calc_for(period_6, ban_tac_huan)
      expect(calc_6.water_pump_standard).to eq_display("60.00")

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T18 — Tính toán lại kỳ đã đóng cho kết quả y hệt (idempotent từ snapshot)" do
    include_context "với kỳ tháng 5 đã đóng + kỳ tháng 6 mở"

    it "recalculate kỳ 5 sau khi đã sửa nhiều thứ ở kỳ 6 vẫn ra số gốc" do
      period_6.update!(unit_price: BigDecimal("9999"), savings_rate: BigDecimal("20"))
      ha_si_quan_p6 = period_6.ranks.find_by(position: 7)
      ha_si_quan_p6.update!(quota: BigDecimal("1000"))

      service.close_period(period_6)
      service.reopen_period(period_5)

      CalculationOrchestrator.new(zone: sample.zone, period: period_5).call

      expect(snapshot_calculations(period_5)).to eq(snapshot_period_5_before)
    end
  end

  describe "T25 — Thêm đầu mối khi kỳ đang mở" do
    it "tự tạo personnel_entries, other_deductions, meter_readings cho kỳ hiện tại" do
      period = sample.period
      ha_si_quan = sample.ranks[:ha_si_quan]
      to_xe = create(:contact_point, :residential, name: "Tổ xe", unit: sample.unit_a,
                     initial_personnel_counts: { ha_si_quan.id => 3 })
      ct_tx = create(:meter, name: "CT-TX", contact_point: to_xe, no_loss: false)

      expect(PersonnelEntry.where(contact_point: to_xe, period: period).count).to eq(7)
      hsq_entry = PersonnelEntry.find_by(contact_point: to_xe, period: period, rank: ha_si_quan)
      expect(hsq_entry.count).to eq(3)

      other = OtherDeduction.find_by(contact_point: to_xe, period: period)
      expect(other.other_type).to eq("fixed")
      expect(other.other_value).to eq(0)

      reading = MeterReading.find_by(meter: ct_tx, period: period)
      expect(reading.reading_start).to eq(0)
      expect(reading.reading_end).to be_nil
      expect(reading.no_loss).to be false
    end
  end

  describe "T26 — Thêm đầu mối khi không có kỳ đang mở" do
    it "đầu mối tạo thành công, không có snapshot cho bất kỳ kỳ nào" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      cp = create(:contact_point, :residential, name: "Tổ bảo vệ", unit: unit)
      meter = create(:meter, name: "CT-TBV", contact_point: cp)

      expect(cp.personnel_entries).to be_empty
      expect(cp.other_deductions).to be_empty
      expect(meter.meter_readings).to be_empty
      expect(cp).to be_persisted
    end
  end
end
