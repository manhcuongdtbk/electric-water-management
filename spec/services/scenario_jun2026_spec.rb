require "rails_helper"

# Integration scenario — Kịch bản tháng 6/2026.
#
# Data độc lập hoàn toàn với scenario_may2026_spec (không reuse), nhưng mô
# phỏng "kế thừa" T5: đầu kỳ công tơ T6 = cuối kỳ T5.
#
# Khác biệt nghiệp vụ so với T5:
#   * đơn giá 2500, công tơ tổng supply 2200
#   * A2 quân số tăng (rank7: 3 → 4)
#   * thêm đầu mối B2 (DVB)
#   * CPG1 chuyển từ fixed 20% → variable (không còn fixed_pump_percentage)
#   * công tơ bơm tiêu thụ 400 (T5 là 500)
#
# Expected values tính độc lập bằng Python BigDecimal, tolerance bd("0.01").
RSpec.describe "Kịch bản tháng 6/2026" do
  def bd(value) = BigDecimal(value.to_s)

  let(:tolerance) { bd("0.01") }

  # Sư đoàn + Zone
  let_it_be(:division) { create(:organization, :division) }
  let_it_be(:zone) { create(:zone, name: "Khu vực chính") }

  # Đơn vị
  let_it_be(:dva) { create(:organization, :unit, parent: division, zone: zone, name: "Đơn vị A") }
  let_it_be(:dvb) { create(:organization, :unit, parent: division, zone: zone, name: "Đơn vị B") }

  before_all { zone.update!(manager_organization: dva) }

  # Period + đơn giá tháng 6
  let_it_be(:period) { create(:monthly_period, year: 2026, month: 6, unit_price: bd("2500")) }

  # Định mức (giống T5)
  let_it_be(:rq1) { create(:rank_quota, rank_group: 1, rank_name: "R1", quota_kw: bd("570")) }
  let_it_be(:rq2) { create(:rank_quota, rank_group: 2, rank_name: "R2", quota_kw: bd("440")) }
  let_it_be(:rq3) { create(:rank_quota, rank_group: 3, rank_name: "R3", quota_kw: bd("305")) }
  let_it_be(:rq4) { create(:rank_quota, rank_group: 4, rank_name: "R4", quota_kw: bd("130")) }
  let_it_be(:rq5) { create(:rank_quota, rank_group: 5, rank_name: "R5", quota_kw: bd("210")) }
  let_it_be(:rq6) { create(:rank_quota, rank_group: 6, rank_name: "R6", quota_kw: bd("110")) }
  let_it_be(:rq7) { create(:rank_quota, rank_group: 7, rank_name: "R7", quota_kw: bd("24")) }

  # Công tơ tổng: supply = 2200 (start 2000 = cuối kỳ T5, end 4200)
  let_it_be(:main_meter) { create(:main_meter, zone: zone, name: "Công tơ tổng 1") }
  let_it_be(:mm_reading) { create(:main_meter_reading, main_meter: main_meter, monthly_period: period, electricity_supply_kw: bd("2200")) }

  # Cấu hình (giống T5)
  let_it_be(:div_config) { create(:unit_config, organization: division, monthly_period: period, savings_rate: bd("0.05"), division_public_rate: bd("0.10"), unit_public_rate: bd("0")) }
  let_it_be(:dva_config) { create(:unit_config, organization: dva, monthly_period: period, savings_rate: bd("0"), division_public_rate: bd("0"), unit_public_rate: bd("0.08")) }
  let_it_be(:dvb_config) { create(:unit_config, organization: dvb, monthly_period: period, savings_rate: bd("0"), division_public_rate: bd("0"), unit_public_rate: bd("0.05")) }

  # --- Đầu mối DVA ---
  # A1: 2 người (không đổi). Công tơ start 800 (= cuối kỳ T5) → end 1500, usage 700.
  let_it_be(:a1) { create(:contact_point, :residential, organization: dva, name: "A1 — Ban Chỉ huy") }
  let_it_be(:a1_meter) { create(:meter, :normal, organization: dva, contact_point: a1, name: "A1-CT1") }
  let_it_be(:a1_reading) { create(:meter_reading, meter: a1_meter, monthly_period: period, reading_start: 800, reading_end: 1500, consumption: 700) }
  let_it_be(:a1_personnel) { create(:personnel, contact_point: a1, monthly_period: period, rank1_count: 1, rank2_count: 1, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # A2: quân số tăng → 4 Binh sĩ. 2 công tơ, tổng usage 100.
  let_it_be(:a2) { create(:contact_point, :residential, organization: dva, name: "A2 — Tổ xe") }
  let_it_be(:a2_meter1) { create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT1") }
  let_it_be(:a2_reading1) { create(:meter_reading, meter: a2_meter1, monthly_period: period, reading_start: 50, reading_end: 110, consumption: 60) }
  let_it_be(:a2_meter2) { create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT2") }
  let_it_be(:a2_reading2) { create(:meter_reading, meter: a2_meter2, monthly_period: period, reading_start: 30, reading_end: 70, consumption: 40) }
  let_it_be(:a2_personnel) { create(:personnel, contact_point: a2, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 4) }

  # A3: 1 cấp Úy, công tơ NO_LOSS. start 100 → end 180, usage 80.
  let_it_be(:a3) { create(:contact_point, :residential, organization: dva, name: "A3 — Kho") }
  let_it_be(:a3_meter) { create(:meter, :normal, organization: dva, contact_point: a3, name: "A3-CT1", no_loss: true) }
  let_it_be(:a3_reading) { create(:meter_reading, meter: a3_meter, monthly_period: period, reading_start: 100, reading_end: 180, consumption: 80) }
  let_it_be(:a3_personnel) { create(:personnel, contact_point: a3, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 1, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # A4: Đèn đường, communal, public_meter. start 200 → end 350, usage 150.
  let_it_be(:a4) { create(:contact_point, :communal, organization: dva, name: "A4 — Đèn đường") }
  let_it_be(:a4_meter) { create(:meter, :public_meter, organization: dva, contact_point: a4, name: "A4-CT1") }
  let_it_be(:a4_reading) { create(:meter_reading, meter: a4_meter, monthly_period: period, reading_start: 200, reading_end: 350, consumption: 150) }

  # --- Đầu mối DVB ---
  # B1: 5 người (không đổi). start 100 → end 250, usage 150.
  let_it_be(:b1) { create(:contact_point, :residential, organization: dvb, name: "B1 — Đại đội 1") }
  let_it_be(:b1_meter) { create(:meter, :normal, organization: dvb, contact_point: b1, name: "B1-CT1") }
  let_it_be(:b1_reading) { create(:meter_reading, meter: b1_meter, monthly_period: period, reading_start: 100, reading_end: 250, consumption: 150) }
  let_it_be(:b1_personnel) { create(:personnel, contact_point: b1, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 2, rank6_count: 0, rank7_count: 3) }

  # B2: đầu mối MỚI tháng 6 — 1 Trung tá. Công tơ start 0 → end 60, usage 60.
  let_it_be(:b2) { create(:contact_point, :residential, organization: dvb, name: "B2 — Đại đội 2") }
  let_it_be(:b2_meter) { create(:meter, :normal, organization: dvb, contact_point: b2, name: "B2-CT1") }
  let_it_be(:b2_reading) { create(:meter_reading, meter: b2_meter, monthly_period: period, reading_start: 0, reading_end: 60, consumption: 60) }
  let_it_be(:b2_personnel) { create(:personnel, contact_point: b2, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 1, rank7_count: 0) }

  # --- Trạm bơm --- start 500 (= cuối kỳ T5) → end 900, usage 400.
  let_it_be(:pump_station) { create(:pump_station, zone: zone, name: "TB1") }
  let_it_be(:pump_meter) { create(:meter, :pump_station, organization: dva, pump_station: pump_station, name: "TB1-CT1") }
  let_it_be(:pump_reading) { create(:meter_reading, meter: pump_meter, monthly_period: period, reading_start: 500, reading_end: 900, consumption: 400) }

  # --- Nhóm công tác ---
  let_it_be(:work_group) { create(:work_group, owner_organization: dva, name: "Thợ xây", personnel_count: 2) }

  # --- Nhóm đầu mối CPG1 (A2+A3) ---
  let_it_be(:cpg1) { create(:contact_point_group, organization: dva, name: "CPG1") }
  let_it_be(:cpg1_m1) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: a2) }
  let_it_be(:cpg1_m2) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: a3) }

  # --- Gán bơm --- CPG1 KHÔNG còn fixed % (variable), A1 vẫn fixed 30%.
  let_it_be(:asg_a1) { create(:pump_station_assignment, pump_station: pump_station, assignable: a1, fixed_pump_percentage: 30) }
  let_it_be(:asg_cpg1) { create(:pump_station_assignment, pump_station: pump_station, assignable: cpg1) }
  let_it_be(:asg_dva) { create(:pump_station_assignment, pump_station: pump_station, assignable: dva) }
  let_it_be(:asg_dvb) { create(:pump_station_assignment, pump_station: pump_station, assignable: dvb) }
  let_it_be(:asg_wg) { create(:pump_station_assignment, pump_station: pump_station, assignable: work_group) }

  context "DVA" do
    let(:results) { CalculationOrchestrator.new(organization: dva, monthly_period: period).compute }
    let(:result_a1) { results.find { |r| r[:contact_point_id] == a1.id } }
    let(:result_a2) { results.find { |r| r[:contact_point_id] == a2.id } }
    let(:result_a3) { results.find { |r| r[:contact_point_id] == a3.id } }

    it "A1 — Ban Chỉ huy (THIẾU điện)" do
      expect(result_a1[:total_personnel]).to eq(2)
      expect(result_a1[:total_standard_kw]).to be_within(tolerance).of(bd("1028.9"))
      expect(result_a1[:loss_deduction_kw]).to be_within(tolerance).of(bd("251.282"))
      expect(result_a1[:remaining_standard_kw]).to be_within(tolerance).of(bd("540.971"))
      expect(result_a1[:meter_usage_kw]).to eq(bd("700"))
      expect(result_a1[:water_pump_actual_kw]).to be_within(tolerance).of(bd("201.128"))
      expect(result_a1[:total_usage_kw]).to be_within(tolerance).of(bd("901.128"))
      expect(result_a1[:over_under_kw]).to be_within(tolerance).of(bd("360.157"))  # positive = deficit
    end

    it "A2 — Tổ xe (quân số tăng → 4)" do
      expect(result_a2[:total_personnel]).to eq(4)
      expect(result_a2[:total_standard_kw]).to be_within(tolerance).of(bd("133.8"))
      expect(result_a2[:loss_deduction_kw]).to be_within(tolerance).of(bd("35.897"))
      expect(result_a2[:remaining_standard_kw]).to be_within(tolerance).of(bd("67.129"))
      expect(result_a2[:meter_usage_kw]).to eq(bd("100"))  # 60 + 40
      expect(result_a2[:water_pump_actual_kw]).to be_within(tolerance).of(bd("152.205"))
      expect(result_a2[:total_usage_kw]).to be_within(tolerance).of(bd("252.205"))
      expect(result_a2[:over_under_kw]).to be_within(tolerance).of(bd("185.077"))
    end

    it "A3 — Kho (no_loss, tổn hao = 0)" do
      expect(result_a3[:total_personnel]).to eq(1)
      expect(result_a3[:loss_deduction_kw]).to eq(bd("0"))
      expect(result_a3[:remaining_standard_kw]).to be_within(tolerance).of(bd("107.377"))
      expect(result_a3[:water_pump_actual_kw]).to be_within(tolerance).of(bd("38.051"))
      expect(result_a3[:total_usage_kw]).to be_within(tolerance).of(bd("118.051"))
      expect(result_a3[:over_under_kw]).to be_within(tolerance).of(bd("10.675"))
    end
  end

  context "DVB" do
    let(:results) { CalculationOrchestrator.new(organization: dvb, monthly_period: period).compute }
    let(:result_b1) { results.find { |r| r[:contact_point_id] == b1.id } }
    let(:result_b2) { results.find { |r| r[:contact_point_id] == b2.id } }

    it "B1 — Đại đội 1 (THỪA điện)" do
      expect(result_b1[:total_personnel]).to eq(5)
      expect(result_b1[:total_standard_kw]).to be_within(tolerance).of(bd("539.25"))
      expect(result_b1[:remaining_standard_kw]).to be_within(tolerance).of(bd("377.554"))
      expect(result_b1[:meter_usage_kw]).to eq(bd("150"))
      expect(result_b1[:water_pump_actual_kw]).to be_within(tolerance).of(bd("95.128"))
      expect(result_b1[:total_usage_kw]).to be_within(tolerance).of(bd("245.128"))
      expect(result_b1[:over_under_kw]).to be_within(tolerance).of(bd("-132.426"))  # negative = surplus
    end

    it "B2 — Đại đội 2 (đầu mối mới tháng 6)" do
      expect(result_b2[:total_personnel]).to eq(1)
      expect(result_b2[:total_standard_kw]).to be_within(tolerance).of(bd("119.45"))
      expect(result_b2[:loss_deduction_kw]).to be_within(tolerance).of(bd("21.538"))
      expect(result_b2[:remaining_standard_kw]).to be_within(tolerance).of(bd("74.022"))
      expect(result_b2[:meter_usage_kw]).to eq(bd("60"))
      expect(result_b2[:water_pump_actual_kw]).to be_within(tolerance).of(bd("19.026"))
      expect(result_b2[:total_usage_kw]).to be_within(tolerance).of(bd("79.026"))
      expect(result_b2[:over_under_kw]).to be_within(tolerance).of(bd("5.004"))
    end
  end

  context "zone-wide" do
    it "total loss = 560" do
      loss = LossCalculator.new(zone: zone, monthly_period: period).call
      expect(loss[:total_zone_loss]).to be_within(tolerance).of(bd("560"))
    end

    it "total pump pool ≈ 543.59" do
      pump = PumpAllocationCalculator.new(zone: zone, monthly_period: period).call
      expect(pump[:total_pool_kw]).to be_within(tolerance).of(bd("543.59"))
    end

    it "no warnings (supply > consumption)" do
      loss = LossCalculator.new(zone: zone, monthly_period: period).call
      expect(loss[:warnings]).to eq([])
    end
  end
end
