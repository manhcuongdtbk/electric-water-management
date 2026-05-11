require "rails_helper"

# Zone-based loss + pump-in-pool integration scenario (PR2 fix).
#
# Manual-math fixture (numbers picked so total_zone_loss = 220):
#
#   Zone (1 MainMeter) shared by DVA + DVB.
#   DVA:
#     A1 "Ban Chỉ huy"  — 2 ppl (1 Đại tá 570 + 1 Thượng tá 440) | A1-CT1 normal 800
#     A2 "Tổ xe"        — 3 Binh sĩ (24)                          | A2-CT1 normal 50, A2-CT2 normal 30
#     A3 "Kho"          — 1 Cấp úy (130)                          | A3-CT1 no_loss 100   (subtracted from supply)
#     A4 "Đèn đường"    — public CP, 0 personnel                  | A4-CT1 public_meter 200
#   DVB:
#     B1 "Đại đội 1"    — 5 Binh sĩ (24)                          | B1-CT1 normal 100
#   Pump:
#     TB1 (admin at division) assigned to DVA only                | TB1-CT1 pump 500
#
#   supply (MainMeterReading) = 2000
#     A = 2000 − 100 (no_loss) = 1900
#     B = 800 + 50 + 30 + 200 + 100 + 500 = 1680
#     total_zone_loss = 1900 − 1680 = 220
#
#   pump_loss_share(TB1) = 220 × 500 / 1680 = 65.476…
#   ΣCP_loss            = 220 × 1180 / 1680 ≈ 154.524…  (1180 = 800+50+30+200+100)
#   pump_pool           = 500 + 65.476… = 565.476…
#
#   Pump is allocated to DVA's CPs by personnel (total 6: A1=2, A2=3, A3=1, A4=0):
#     A1 → 565.476 × 2/6 ≈ 188.49
#     A2 → 565.476 × 3/6 ≈ 282.74
#     A3 → 565.476 × 1/6 ≈ 94.25
#     A4 → 0
#
# All arithmetic uses BigDecimal; assertions are tolerance-based (0.01 kW)
# because the divisions are irrational.
RSpec.describe "CalculationEngine zone-loss + pump pool (integration)" do
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

  let!(:cfg_dva) do
    create(:unit_config,
           organization: dva, monthly_period: period,
           savings_rate: bd("0.05"), division_public_rate: bd("0.10"),
           unit_public_rate: bd("0"))
  end

  let!(:cfg_dvb) do
    create(:unit_config,
           organization: dvb, monthly_period: period,
           savings_rate: bd("0.05"), division_public_rate: bd("0.10"),
           unit_public_rate: bd("0"))
  end

  # DVA contact points + personnel + meters
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
  # A4 (đèn đường) has no personnel record — public CP.

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

  # DVB contact points + personnel + meter
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

  # Pump at division-level, assigned to DVA only.
  let!(:pump_station) { create(:pump_station, organization: division, name: "TB1") }
  let!(:m_pump) do
    m = create(:meter, :pump_station, organization: division, contact_point: nil, pump_station: pump_station, name: "TB1-CT1")
    create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500)
    m
  end
  let!(:pump_assignment) { create(:pump_station_assignment, pump_station: pump_station, organization: dva) }

  let(:tolerance) { bd("0.01") }

  let(:engine_dva) { CalculationEngine.new(organization: dva, monthly_period: period) }
  let(:engine_dvb) { CalculationEngine.new(organization: dvb, monthly_period: period) }

  describe "zone-wide loss" do
    let(:results_dva) { engine_dva.compute }
    let(:results_dvb) { engine_dvb.compute }

    it "computes total_zone_loss = 220 (= 2000 - 100 - 1680)" do
      cp_loss     = (results_dva + results_dvb).sum { |r| r[:loss_deduction_kw] }
      pump_actual = results_dva.sum { |r| r[:water_pump_actual_kw] }
      # Pump assigned to DVA only → its share of zone loss is reflected entirely
      # in DVA's pump pool: pump_loss_share = pump_actual_sum − 500 (raw consumption).
      pump_loss_share = pump_actual - bd("500")

      expect(cp_loss + pump_loss_share).to be_within(tolerance).of(bd("220"))
    end

    it "allocates CP loss by per-CP meter kW share over B = 1680" do
      a1_row = results_dva.find { |r| r[:contact_point_id] == a1.id }
      a2_row = results_dva.find { |r| r[:contact_point_id] == a2.id }
      a3_row = results_dva.find { |r| r[:contact_point_id] == a3.id }
      a4_row = results_dva.find { |r| r[:contact_point_id] == a4.id }
      b1_row = results_dvb.find { |r| r[:contact_point_id] == b1.id }

      expect(a1_row[:loss_deduction_kw]).to be_within(tolerance).of(bd("220") * bd("800")  / bd("1680"))   # ≈ 104.762
      expect(a2_row[:loss_deduction_kw]).to be_within(tolerance).of(bd("220") * bd("80")   / bd("1680"))   # 50+30, ≈ 10.476
      expect(a3_row[:loss_deduction_kw]).to eq(bd("0"))                                                    # no_loss only
      expect(a4_row[:loss_deduction_kw]).to be_within(tolerance).of(bd("220") * bd("200")  / bd("1680"))   # ≈ 26.190
      expect(b1_row[:loss_deduction_kw]).to be_within(tolerance).of(bd("220") * bd("100")  / bd("1680"))   # ≈ 13.095
    end

    it "isolates no_loss meter consumption from meter_usage_kw (A3 = 0)" do
      a3_row = results_dva.find { |r| r[:contact_point_id] == a3.id }
      expect(a3_row[:meter_usage_kw]).to eq(bd("0"))
    end
  end

  describe "pump pool" do
    let(:expected_pump_loss_share) { bd("220") * bd("500") / bd("1680") } # ≈ 65.476
    let(:expected_pump_pool)       { bd("500") + expected_pump_loss_share }  # ≈ 565.476

    it "inflates pump pool to consumption + pump's share of zone loss" do
      pump_actual_total = engine_dva.compute.sum { |r| r[:water_pump_actual_kw] }
      expect(pump_actual_total).to be_within(tolerance).of(expected_pump_pool)
    end

    it "distributes pump pool to DVA CPs by personnel (6 total: A1=2, A2=3, A3=1, A4=0)" do
      results = engine_dva.compute
      a1_row = results.find { |r| r[:contact_point_id] == a1.id }
      a2_row = results.find { |r| r[:contact_point_id] == a2.id }
      a3_row = results.find { |r| r[:contact_point_id] == a3.id }
      a4_row = results.find { |r| r[:contact_point_id] == a4.id }

      expect(a1_row[:water_pump_actual_kw]).to be_within(tolerance).of(expected_pump_pool * bd("2") / bd("6"))
      expect(a2_row[:water_pump_actual_kw]).to be_within(tolerance).of(expected_pump_pool * bd("3") / bd("6"))
      expect(a3_row[:water_pump_actual_kw]).to be_within(tolerance).of(expected_pump_pool * bd("1") / bd("6"))
      expect(a4_row[:water_pump_actual_kw]).to eq(bd("0"))
    end

    it "DVB receives no pump (no PumpStationAssignment to DVB)" do
      expect(engine_dvb.compute.sum { |r| r[:water_pump_actual_kw] }).to eq(bd("0"))
    end
  end

  describe "org with no MainMeter (no supply available)" do
    let(:solo_org) { create(:organization, level: :unit, parent: division, code: "SOLO", main_meter: nil) }
    let!(:solo_cfg) do
      create(:unit_config, organization: solo_org, monthly_period: period,
             savings_rate: bd("0.05"), division_public_rate: bd("0.10"),
             unit_public_rate: bd("0"))
    end
    let!(:cp_solo) { create(:contact_point, organization: solo_org, name: "Solo CP") }
    let!(:p_solo) do
      create(:personnel, contact_point: cp_solo, monthly_period: period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 5)
    end
    let!(:m_solo) do
      m = create(:meter, :normal, organization: solo_org, contact_point: cp_solo, name: "Solo meter")
      create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 400, consumption: 400)
      m
    end

    it "computes zero loss (supply unknown without MainMeter)" do
      engine = CalculationEngine.new(organization: solo_org, monthly_period: period)
      row = engine.compute.find { |r| r[:contact_point_id] == cp_solo.id }
      expect(row[:loss_deduction_kw]).to eq(bd("0"))
    end
  end
end
