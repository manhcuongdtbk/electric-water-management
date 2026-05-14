require "rails_helper"

# Integration scenario — Kịch bản tháng 5/2026.
#
# End-to-end run của CalculationOrchestrator với một bộ số liệu thực tế
# hoàn chỉnh: 1 zone, 2 đơn vị cấp 2, công tơ no_loss, đầu mối công cộng,
# trạm bơm với phân bổ fixed + variable, ContactPointGroup, WorkGroup.
#
# Expected values được tính độc lập bằng Python BigDecimal. So sánh dùng
# tolerance bd("0.01") vì engine giữ full-precision (không làm tròn).
RSpec.describe "Kịch bản tháng 5/2026" do
  def bd(value) = BigDecimal(value.to_s)

  let(:tolerance) { bd("0.01") }

  # Sư đoàn + Zone
  let_it_be(:division) { create(:organization, :division) }
  let_it_be(:zone) { create(:zone, name: "Khu vực chính") }

  # Đơn vị
  let_it_be(:dva) { create(:organization, :unit, parent: division, zone: zone, name: "Đơn vị A") }
  let_it_be(:dvb) { create(:organization, :unit, parent: division, zone: zone, name: "Đơn vị B") }

  # Zone manager
  before_all { zone.update!(manager_organization: dva) }

  # Period + đơn giá
  let_it_be(:period) { create(:monthly_period, year: 2026, month: 5, unit_price: bd("2336.4")) }

  # Định mức
  let_it_be(:rq1) { create(:rank_quota, rank_group: 1, rank_name: "R1", quota_kw: bd("570")) }
  let_it_be(:rq2) { create(:rank_quota, rank_group: 2, rank_name: "R2", quota_kw: bd("440")) }
  let_it_be(:rq3) { create(:rank_quota, rank_group: 3, rank_name: "R3", quota_kw: bd("305")) }
  let_it_be(:rq4) { create(:rank_quota, rank_group: 4, rank_name: "R4", quota_kw: bd("130")) }
  let_it_be(:rq5) { create(:rank_quota, rank_group: 5, rank_name: "R5", quota_kw: bd("210")) }
  let_it_be(:rq6) { create(:rank_quota, rank_group: 6, rank_name: "R6", quota_kw: bd("110")) }
  let_it_be(:rq7) { create(:rank_quota, rank_group: 7, rank_name: "R7", quota_kw: bd("24")) }

  # Công tơ tổng: supply = 2000
  let_it_be(:main_meter) { create(:main_meter, zone: zone, name: "Công tơ tổng 1") }
  let_it_be(:mm_reading) { create(:main_meter_reading, main_meter: main_meter, monthly_period: period, electricity_supply_kw: bd("2000")) }

  # Cấu hình Sư đoàn: tiết kiệm 5%, CC SĐ 10%
  let_it_be(:div_config) { create(:unit_config, organization: division, monthly_period: period, savings_rate: bd("0.05"), division_public_rate: bd("0.10"), unit_public_rate: bd("0")) }

  # Cấu hình DVA: CC đơn vị 8%
  let_it_be(:dva_config) { create(:unit_config, organization: dva, monthly_period: period, savings_rate: bd("0"), division_public_rate: bd("0"), unit_public_rate: bd("0.08")) }

  # Cấu hình DVB: CC đơn vị 5%
  let_it_be(:dvb_config) { create(:unit_config, organization: dvb, monthly_period: period, savings_rate: bd("0"), division_public_rate: bd("0"), unit_public_rate: bd("0.05")) }

  # --- Đầu mối DVA ---
  # A1: 1 Đại tá + 1 Thượng tá = 2 người
  let_it_be(:a1) { create(:contact_point, :residential, organization: dva, name: "A1 — Ban Chỉ huy") }
  let_it_be(:a1_meter) { create(:meter, :normal, organization: dva, contact_point: a1, name: "A1-CT1") }
  let_it_be(:a1_reading) { create(:meter_reading, meter: a1_meter, monthly_period: period, reading_start: 0, reading_end: 800, consumption: 800) }
  let_it_be(:a1_personnel) { create(:personnel, contact_point: a1, monthly_period: period, rank1_count: 1, rank2_count: 1, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # A2: 3 Binh sĩ = 3 người, 2 công tơ
  let_it_be(:a2) { create(:contact_point, :residential, organization: dva, name: "A2 — Tổ xe") }
  let_it_be(:a2_meter1) { create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT1") }
  let_it_be(:a2_reading1) { create(:meter_reading, meter: a2_meter1, monthly_period: period, reading_start: 0, reading_end: 50, consumption: 50) }
  let_it_be(:a2_meter2) { create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT2") }
  let_it_be(:a2_reading2) { create(:meter_reading, meter: a2_meter2, monthly_period: period, reading_start: 0, reading_end: 30, consumption: 30) }
  let_it_be(:a2_personnel) { create(:personnel, contact_point: a2, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 3) }

  # A3: 1 cấp Úy = 1 người, công tơ NO_LOSS
  let_it_be(:a3) { create(:contact_point, :residential, organization: dva, name: "A3 — Kho") }
  let_it_be(:a3_meter) { create(:meter, :normal, organization: dva, contact_point: a3, name: "A3-CT1", no_loss: true) }
  let_it_be(:a3_reading) { create(:meter_reading, meter: a3_meter, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100) }
  let_it_be(:a3_personnel) { create(:personnel, contact_point: a3, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 1, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # A4: Đèn đường, communal, 0 quân số, public_meter
  let_it_be(:a4) { create(:contact_point, :communal, organization: dva, name: "A4 — Đèn đường") }
  let_it_be(:a4_meter) { create(:meter, :public_meter, organization: dva, contact_point: a4, name: "A4-CT1") }
  let_it_be(:a4_reading) { create(:meter_reading, meter: a4_meter, monthly_period: period, reading_start: 0, reading_end: 200, consumption: 200) }

  # --- Đầu mối DVB ---
  # B1: 2 cấp Trung tá + 3 Binh sĩ = 5 người
  let_it_be(:b1) { create(:contact_point, :residential, organization: dvb, name: "B1 — Đại đội 1") }
  let_it_be(:b1_meter) { create(:meter, :normal, organization: dvb, contact_point: b1, name: "B1-CT1") }
  let_it_be(:b1_reading) { create(:meter_reading, meter: b1_meter, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100) }
  let_it_be(:b1_personnel) { create(:personnel, contact_point: b1, monthly_period: period, rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 2, rank6_count: 0, rank7_count: 3) }

  # --- Trạm bơm ---
  let_it_be(:pump_station) { create(:pump_station, zone: zone, name: "TB1") }
  let_it_be(:pump_meter) { create(:meter, :pump_station, organization: dva, pump_station: pump_station, name: "TB1-CT1") }
  let_it_be(:pump_reading) { create(:meter_reading, meter: pump_meter, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500) }

  # --- Nhóm công tác ---
  let_it_be(:work_group) { create(:work_group, owner_organization: dva, name: "Thợ xây", personnel_count: 2) }

  # --- Nhóm đầu mối CPG1 (A2+A3) ---
  let_it_be(:cpg1) { create(:contact_point_group, organization: dva, name: "CPG1") }
  let_it_be(:cpg1_m1) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: a2) }
  let_it_be(:cpg1_m2) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: a3) }

  # --- Gán bơm ---
  let_it_be(:asg_a1) { create(:pump_station_assignment, pump_station: pump_station, assignable: a1, fixed_pump_percentage: 30) }
  let_it_be(:asg_cpg1) { create(:pump_station_assignment, pump_station: pump_station, assignable: cpg1, fixed_pump_percentage: 20) }
  let_it_be(:asg_dva) { create(:pump_station_assignment, pump_station: pump_station, assignable: dva) }
  let_it_be(:asg_dvb) { create(:pump_station_assignment, pump_station: pump_station, assignable: dvb) }
  let_it_be(:asg_wg) { create(:pump_station_assignment, pump_station: pump_station, assignable: work_group) }

  context "DVA" do
    let(:results) { CalculationOrchestrator.new(organization: dva, monthly_period: period).compute }
    let(:result_a1) { results.find { |r| r[:contact_point_id] == a1.id } }
    let(:result_a2) { results.find { |r| r[:contact_point_id] == a2.id } }
    let(:result_a3) { results.find { |r| r[:contact_point_id] == a3.id } }

    # compute() tính + persist mọi CP (kể cả communal — public meter của chúng
    # tham gia tính tổn hao). Communal CP chỉ bị loại khỏi BẢNG THU TIỀN F11/F12
    # qua scope MonthlyCalculation.excluding_communal_cps.
    it "includes communal CP (A4) in compute output but excludes it from the billing table" do
      expect(results.map { |r| r[:contact_point_id] }).to include(a4.id)

      CalculationOrchestrator.new(organization: dva, monthly_period: period).call
      billing_cp_ids = MonthlyCalculation.excluding_communal_cps
                                         .where(monthly_period: period)
                                         .pluck(:contact_point_id)
      expect(billing_cp_ids).to include(a1.id, a2.id, a3.id)
      expect(billing_cp_ids).not_to include(a4.id)
    end

    it "A1 — Ban Chỉ huy" do
      expect(result_a1[:total_personnel]).to eq(2)
      expect(result_a1[:total_standard_kw]).to be_within(tolerance).of(bd("1028.9"))
      expect(result_a1[:savings_deduction_kw]).to be_within(tolerance).of(bd("51.445"))
      expect(result_a1[:loss_deduction_kw]).to be_within(tolerance).of(bd("104.762"))
      expect(result_a1[:division_public_deduction_kw]).to be_within(tolerance).of(bd("102.89"))
      expect(result_a1[:unit_public_deduction_kw]).to be_within(tolerance).of(bd("82.312"))
      expect(result_a1[:remaining_standard_kw]).to be_within(tolerance).of(bd("687.491"))
      expect(result_a1[:meter_usage_kw]).to eq(bd("800"))
      expect(result_a1[:water_pump_actual_kw]).to be_within(tolerance).of(bd("213.141"))
      expect(result_a1[:total_usage_kw]).to be_within(tolerance).of(bd("1013.141"))
      expect(result_a1[:over_under_kw]).to be_within(tolerance).of(bd("325.65"))  # positive = deficit
    end

    it "A2 — Tổ xe (2 công tơ)" do
      expect(result_a2[:total_personnel]).to eq(3)
      expect(result_a2[:total_standard_kw]).to be_within(tolerance).of(bd("100.35"))
      expect(result_a2[:loss_deduction_kw]).to be_within(tolerance).of(bd("10.476"))
      expect(result_a2[:meter_usage_kw]).to eq(bd("80"))  # 50 + 30
      expect(result_a2[:water_pump_actual_kw]).to be_within(tolerance).of(bd("150.069"))
      expect(result_a2[:over_under_kw]).to be_within(tolerance).of(bd("163.275"))
    end

    it "A3 — Kho (no_loss, tổn hao = 0)" do
      expect(result_a3[:total_personnel]).to eq(1)
      expect(result_a3[:loss_deduction_kw]).to eq(bd("0"))
      expect(result_a3[:remaining_standard_kw]).to be_within(tolerance).of(bd("107.377"))
      expect(result_a3[:water_pump_actual_kw]).to be_within(tolerance).of(bd("50.023"))
      expect(result_a3[:over_under_kw]).to be_within(tolerance).of(bd("42.646"))
    end
  end

  context "DVB" do
    let(:results) { CalculationOrchestrator.new(organization: dvb, monthly_period: period).compute }
    let(:result_b1) { results.find { |r| r[:contact_point_id] == b1.id } }

    it "B1 — Đại đội 1 (THỪA điện)" do
      expect(result_b1[:total_personnel]).to eq(5)
      expect(result_b1[:total_standard_kw]).to be_within(tolerance).of(bd("539.25"))
      expect(result_b1[:unit_public_deduction_kw]).to be_within(tolerance).of(bd("26.963"))  # 5% DVB
      expect(result_b1[:remaining_standard_kw]).to be_within(tolerance).of(bd("418.305"))
      expect(result_b1[:water_pump_actual_kw]).to be_within(tolerance).of(bd("108.745"))
      expect(result_b1[:total_usage_kw]).to be_within(tolerance).of(bd("208.745"))
      expect(result_b1[:over_under_kw]).to be_within(tolerance).of(bd("-209.559"))  # negative = surplus
    end
  end

  context "zone-wide" do
    it "total loss = 220" do
      loss = LossCalculator.new(zone: zone, monthly_period: period).call
      expect(loss[:total_zone_loss]).to be_within(tolerance).of(bd("220"))
    end

    it "total pump pool ≈ 565.476" do
      pump = PumpAllocationCalculator.new(zone: zone, monthly_period: period).call
      expect(pump[:total_pool_kw]).to be_within(tolerance).of(bd("565.476"))
    end

    it "no warnings (supply > consumption)" do
      loss = LossCalculator.new(zone: zone, monthly_period: period).call
      expect(loss[:warnings]).to eq([])
    end
  end
end
