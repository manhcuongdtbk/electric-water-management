require "rails_helper"

# Integration scenario for "3 loại nhóm đối tượng" pump allocation (m6).
#
# Extends the zone-loss scenario by replacing the single Organization-level
# assignment with FOUR assignments that exercise all three assignable types:
#
#   - A1 (ContactPoint, đầu mối đặc biệt)  fixed 30%
#   - DVA (Organization)                    variable
#   - DVB (Organization)                    variable
#   - "Tho xay" (WorkGroup, nhóm công tác)  variable
#
# Manual math (BigDecimal, no intermediate rounding):
#
#   supply = 2000, no_loss = 100, loss-pool B = 1680 → total_zone_loss = 220.
#   pump_loss_share(TB1) = 220 × 500 / 1680 ≈ 65.476
#   pump pool             = 500 + 65.476 ≈ 565.476
#
#   Fixed 30% to A1                       = 565.476 × 0.30  ≈ 169.643
#   Variable pool 70%                     = 565.476 × 0.70  ≈ 395.833
#   Variable headcount: DVA 6 + DVB 5 + WG 2 = 13
#     DVA → 395.833 × 6/13 ≈ 182.692 → split by personnel within DVA:
#       A1 ← 182.692 × 2/6 ≈ 60.897
#       A2 ← 182.692 × 3/6 ≈ 91.346
#       A3 ← 182.692 × 1/6 ≈ 30.449
#       A4 ← 0 (no personnel)
#     DVB → 395.833 × 5/13 ≈ 152.244 → all to B1
#     "Tho xay" (WG) → 395.833 × 2/13 ≈ 60.897 (reported via service, not MC)
#
#   A1 total = 169.643 (CP fixed) + 60.897 (DVA share) ≈ 230.540
#   A1.total_usage = 800 (meter) + 230.540 (pump)  ≈ 1030.540
#
# All A1 stacking is intentional: when a CP is fixed AND its parent Org is
# variable, the engine credits both routes (admin chose the layout).
RSpec.describe "Pump allocation across 3 nhóm đối tượng (integration)" do
  def bd(value) = BigDecimal(value.to_s)

  let(:division)    { create(:organization, :division) }
  let(:main_meter)  { create(:main_meter, name: "Khu vuc A") }
  let(:dva)         { create(:organization, level: :unit, parent: division, code: "DVA", name: "DVA", main_meter: main_meter) }
  let(:dvb)         { create(:organization, level: :unit, parent: division, code: "DVB", name: "DVB", main_meter: main_meter) }
  let(:period)      { create(:monthly_period, year: 2026, month: 4, unit_price: bd("2336.4")) }

  let!(:rank_quotas) { (1..7).map { |g| create(:rank_quota, :"rank#{g}") } }

  let!(:supply_reading) do
    create(:main_meter_reading,
           main_meter: main_meter, monthly_period: period,
           electricity_supply_kw: bd("2000"))
  end

  # Division-level config holds savings_rate + division_public_rate. Unit
  # rows omitted — unit_public_rate defaults to ZERO when missing.
  let!(:cfg_division) do
    create(:unit_config,
           organization: division, monthly_period: period,
           savings_rate: bd("0.05"), division_public_rate: bd("0.10"),
           unit_public_rate: nil)
  end

  let!(:a1) { create(:contact_point, organization: dva, name: "A1 Ban Chi huy", position: 1) }
  let!(:a2) { create(:contact_point, organization: dva, name: "A2 To xe",      position: 2) }
  let!(:a3) { create(:contact_point, organization: dva, name: "A3 Kho",         position: 3) }
  let!(:a4) { create(:contact_point, organization: dva, name: "A4 Den duong",   group_name: "public", position: 4) }

  let!(:p_a1) do
    create(:personnel, contact_point: a1, monthly_period: period,
           rank1_count: 1, rank2_count: 1, rank3_count: 0, rank4_count: 0,
           rank5_count: 0, rank6_count: 0, rank7_count: 0)
  end
  let!(:p_a2) do
    create(:personnel, contact_point: a2, monthly_period: period,
           rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0,
           rank5_count: 0, rank6_count: 0, rank7_count: 3)
  end
  let!(:p_a3) do
    create(:personnel, contact_point: a3, monthly_period: period,
           rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 1,
           rank5_count: 0, rank6_count: 0, rank7_count: 0)
  end

  let!(:m_a1) do
    m = create(:meter, :normal, organization: dva, contact_point: a1, name: "A1-CT1")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 800, consumption: 800)
    m
  end
  let!(:m_a2_1) do
    m = create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT1")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 50, consumption: 50)
    m
  end
  let!(:m_a2_2) do
    m = create(:meter, :normal, organization: dva, contact_point: a2, name: "A2-CT2")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 30, consumption: 30)
    m
  end
  let!(:m_a3) do
    m = create(:meter, :no_loss, organization: dva, contact_point: a3, name: "A3-CT1 no_loss")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100)
    m
  end
  let!(:m_a4) do
    m = create(:meter, :public_meter, organization: dva, contact_point: a4, name: "A4-CT1 public")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 200, consumption: 200)
    m
  end

  let!(:b1) { create(:contact_point, organization: dvb, name: "B1 Dai doi 1", position: 1) }
  let!(:p_b1) do
    create(:personnel, contact_point: b1, monthly_period: period,
           rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0,
           rank5_count: 0, rank6_count: 0, rank7_count: 5)
  end
  let!(:m_b1) do
    m = create(:meter, :normal, organization: dvb, contact_point: b1, name: "B1-CT1")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100)
    m
  end

  let!(:pump_station) { create(:pump_station, organization: division, name: "TB1") }
  let!(:m_pump) do
    m = create(:meter, :pump_station, organization: division, contact_point: nil,
               pump_station: pump_station, name: "TB1-CT1")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500)
    m
  end

  let!(:work_group_tho_xay) do
    create(:work_group, owner_organization: division, name: "Tho xay",
           personnel_count: 2, position: 0)
  end

  let!(:asg_a1) do
    create(:pump_station_assignment, pump_station: pump_station,
           assignable: a1, fixed_pump_percentage: 30)
  end
  let!(:asg_dva) do
    create(:pump_station_assignment, pump_station: pump_station, assignable: dva)
  end
  let!(:asg_dvb) do
    create(:pump_station_assignment, pump_station: pump_station, assignable: dvb)
  end
  let!(:asg_tho_xay) do
    create(:pump_station_assignment, pump_station: pump_station,
           assignable: work_group_tho_xay)
  end

  let(:tolerance) { bd("0.01") }

  let(:engine_dva) { CalculationEngine.new(organization: dva, monthly_period: period) }
  let(:engine_dvb) { CalculationEngine.new(organization: dvb, monthly_period: period) }

  let(:pump_pool)    { bd("500") + (bd("220") * bd("500") / bd("1680")) }
  let(:variable_pool) { pump_pool * bd("0.70") }

  describe "per-CP allocation through CalculationEngine" do
    let(:results_dva) { engine_dva.compute }
    let(:results_dvb) { engine_dvb.compute }

    it "credits A1 with BOTH its CP-level 30% slot AND its slice of DVA's variable share" do
      a1_row = results_dva.find { |r| r[:contact_point_id] == a1.id }
      cp_fixed_share    = pump_pool * bd("0.30")
      dva_variable_share = variable_pool * bd("6") / bd("13")
      a1_from_dva       = dva_variable_share * bd("2") / bd("6")

      expect(a1_row[:water_pump_actual_kw]).to be_within(tolerance)
        .of(cp_fixed_share + a1_from_dva)
      expect(a1_row[:water_pump_actual_kw]).to be_within(tolerance).of(bd("230.540"))
    end

    it "splits DVA's variable share across A2/A3/A4 by personnel" do
      a2_row = results_dva.find { |r| r[:contact_point_id] == a2.id }
      a3_row = results_dva.find { |r| r[:contact_point_id] == a3.id }
      a4_row = results_dva.find { |r| r[:contact_point_id] == a4.id }

      dva_share = variable_pool * bd("6") / bd("13")

      expect(a2_row[:water_pump_actual_kw]).to be_within(tolerance).of(dva_share * bd("3") / bd("6"))
      expect(a3_row[:water_pump_actual_kw]).to be_within(tolerance).of(dva_share * bd("1") / bd("6"))
      expect(a4_row[:water_pump_actual_kw]).to eq(bd("0"))
      expect(a2_row[:water_pump_actual_kw]).to be_within(tolerance).of(bd("91.346"))
      expect(a3_row[:water_pump_actual_kw]).to be_within(tolerance).of(bd("30.449"))
    end

    it "gives DVB its full 5/13 variable share (single CP B1)" do
      b1_row = results_dvb.find { |r| r[:contact_point_id] == b1.id }
      expect(b1_row[:water_pump_actual_kw])
        .to be_within(tolerance).of(variable_pool * bd("5") / bd("13"))
      expect(b1_row[:water_pump_actual_kw]).to be_within(tolerance).of(bd("152.244"))
    end

    it "sets A1 total_usage = meter + pump" do
      a1_row = results_dva.find { |r| r[:contact_point_id] == a1.id }
      expect(a1_row[:total_usage_kw]).to be_within(tolerance).of(bd("1030.540"))
    end

    it "does not surface WorkGroup share through MonthlyCalculation rows" do
      all_rows = results_dva + results_dvb
      cp_sum   = all_rows.sum { |r| r[:water_pump_actual_kw] }
      # The pump pool less the work-group share remains for CPs.
      wg_share = variable_pool * bd("2") / bd("13")
      expect(cp_sum).to be_within(bd("0.05")).of(pump_pool - wg_share)
    end
  end

  describe "PumpAllocationCalculator (F10 báo cáo)" do
    subject(:result) do
      PumpAllocationCalculator.new(pump_station: pump_station, monthly_period: period).call
    end

    it "reports the full pool" do
      expect(result[:total_pool_kw]).to be_within(tolerance).of(pump_pool)
      expect(result[:consumption_kw]).to eq(bd("500"))
      expect(result[:loss_share_kw]).to be_within(tolerance).of(bd("220") * bd("500") / bd("1680"))
    end

    it "includes the WorkGroup share that the engine does not persist" do
      wg_row = result[:allocations].find { |r| r[:assignable_type] == "WorkGroup" }
      expect(wg_row[:assignable_id]).to eq(work_group_tho_xay.id)
      expect(wg_row[:personnel]).to eq(2)
      expect(wg_row[:kw]).to be_within(tolerance).of(variable_pool * bd("2") / bd("13"))
      expect(wg_row[:kw]).to be_within(tolerance).of(bd("60.897"))
    end

    it "conservation: Σ allocations = pool" do
      total = result[:allocations].sum { |r| r[:kw] }
      expect(total).to be_within(bd("0.05")).of(pump_pool)
    end

    it "labels rows by assignable type" do
      types = result[:allocations].map { |r| r[:assignable_type] }.tally
      expect(types).to eq("ContactPoint" => 1, "Organization" => 2, "WorkGroup" => 1)
    end
  end

  describe "edge cases" do
    let(:base_engine) { CalculationEngine.new(organization: dva, monthly_period: period) }

    it "WorkGroup with personnel_count = 0 receives 0 share and doesn't break /0" do
      work_group_tho_xay.update!(personnel_count: 0)
      expect { base_engine.compute }.not_to raise_error

      wg_row = PumpAllocationCalculator
                 .new(pump_station: pump_station, monthly_period: period)
                 .call[:allocations]
                 .find { |r| r[:assignable_type] == "WorkGroup" }
      expect(wg_row[:kw]).to eq(bd("0"))
    end

    it "WorkGroup fixed = 0 → receives 0 and stays out of variable pool" do
      asg_tho_xay.update!(fixed_pump_percentage: 0)
      result = PumpAllocationCalculator
                 .new(pump_station: pump_station, monthly_period: period).call
      wg_row = result[:allocations].find { |r| r[:assignable_type] == "WorkGroup" }
      expect(wg_row[:kw]).to eq(bd("0"))

      # Variable denominator now 11 (6+5), pool unchanged at 70%.
      dva_share = variable_pool * bd("6") / bd("11")
      a2_row = base_engine.compute.find { |r| r[:contact_point_id] == a2.id }
      expect(a2_row[:water_pump_actual_kw]).to be_within(tolerance).of(dva_share * bd("3") / bd("6"))
    end

    it "sum_fixed > 100 → variable allocations get 0 (clamping affects only variable_pct)" do
      asg_a1.update!(fixed_pump_percentage: 80)
      create(:pump_station_assignment, pump_station: pump_station,
             assignable: a2, fixed_pump_percentage: 50)

      result = PumpAllocationCalculator
                 .new(pump_station: pump_station, monthly_period: period).call
      org_rows = result[:allocations].select { |r| r[:assignable_type] == "Organization" }
      wg_row   = result[:allocations].find  { |r| r[:assignable_type] == "WorkGroup" }
      cp_rows  = result[:allocations].select { |r| r[:assignable_type] == "ContactPoint" }

      # Variable pool clamps to 0 (sum_fixed 130 → clamped to 100).
      org_rows.each { |r| expect(r[:kw]).to eq(bd("0")) }
      expect(wg_row[:kw]).to eq(bd("0"))

      # Each fixed slot still receives its raw percentage (sum may exceed pool —
      # admin's responsibility to keep totals sensible).
      a1_row = cp_rows.find { |r| r[:assignable_id] == a1.id }
      a2_row = cp_rows.find { |r| r[:assignable_id] == a2.id }
      expect(a1_row[:kw]).to be_within(tolerance).of(pump_pool * bd("0.80"))
      expect(a2_row[:kw]).to be_within(tolerance).of(pump_pool * bd("0.50"))
    end
  end
end
