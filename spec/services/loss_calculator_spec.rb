require "rails_helper"

# Direct unit specs for LossCalculator — the Loss phase extracted from
# CalculationOrchestrator. Numeric anchors are deliberately shared with
# calculation_orchestrator_spec.rb (Scenario A) and
# calculation_orchestrator_zone_loss_spec.rb (Scenario B) so bit-for-bit
# equivalence with the pre-extraction engine can be spotted at a glance.
#
# Engine integration is still covered by the existing 49 numeric assertions
# in those two specs; this file covers LossCalculator's own contract:
# call output shape, edge cases, and pump_loss_share semantics.
RSpec.describe LossCalculator do
  def bd(value) = BigDecimal(value.to_s)

  # ============================================================ Scenario A
  # Base: 1 MainMeter zone, 3 normal CP meters (99 + 105 + 500 = 704),
  # 1 pump meter (1000). supply 1800 → B = 1704, C = 96.
  describe "Scenario A — base (supply 1800, no no_loss, 3 normal + 1 pump)" do
    let(:division)    { create(:organization, :division) }
    let(:main_meter)  { create(:main_meter, name: "Zone A") }
    let(:zone)        { main_meter.zone }
    let(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
    let(:period)      { create(:monthly_period, year: 2026, month: 2, unit_price: bd("2336.4")) }

    let!(:supply_reading) do
      create(:main_meter_reading,
             main_meter: main_meter, monthly_period: period,
             electricity_supply_kw: bd("1800"))
    end

    let!(:cp_truong)   { create(:contact_point, organization: organization, name: "TMP Truong",   position: 1) }
    let!(:cp_qluc)     { create(:contact_point, organization: organization, name: "TB Q.Luc",     position: 2) }
    let!(:cp_tac_huan) { create(:contact_point, organization: organization, name: "Ban Tac Huan", position: 3) }

    let!(:meter_truong)   { create(:meter, :normal, organization: organization, contact_point: cp_truong,   name: "M-Truong") }
    let!(:meter_qluc)     { create(:meter, :normal, organization: organization, contact_point: cp_qluc,     name: "M-QLuc") }
    let!(:meter_tac_huan) { create(:meter, :normal, organization: organization, contact_point: cp_tac_huan, name: "M-TacHuan") }

    let!(:reading_truong)   { create(:meter_reading, meter: meter_truong,   monthly_period: period, reading_start: 0, reading_end: 99,  consumption: 99) }
    let!(:reading_qluc)     { create(:meter_reading, meter: meter_qluc,     monthly_period: period, reading_start: 0, reading_end: 105, consumption: 105) }
    let!(:reading_tac_huan) { create(:meter_reading, meter: meter_tac_huan, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500) }

    let!(:pump_station) { create(:pump_station, zone: zone, name: "TB 1") }
    let!(:pump_meter)   { create(:meter, :pump_station, organization: division, contact_point: nil, pump_station: pump_station, name: "M-Pump") }
    let!(:pump_reading) { create(:meter_reading, meter: pump_meter, monthly_period: period, reading_start: 0, reading_end: 1000, consumption: 1000) }
    let!(:pump_assignment) { create(:pump_station_assignment, pump_station: pump_station, organization: organization) }

    let(:calc)    { described_class.new(zone: zone, monthly_period: period) }
    let(:results) { calc.call }

    it "returns supply (A) = 1800" do
      expect(results[:zone_supply_kw]).to eq(bd("1800"))
    end

    it "returns B = 1704 (sum of normal 704 + pump 1000)" do
      expect(results[:loss_pool_consumption_in_zone]).to eq(bd("1704"))
    end

    it "returns C = total_zone_loss = 96 (= 1800 - 0 - 1704)" do
      expect(results[:total_zone_loss]).to eq(bd("96"))
    end

    it "returns loss_pool_consumption_by_cp with 3 keys (one per CP)" do
      hash = results[:loss_pool_consumption_by_cp]
      expect(hash.keys).to match_array([ cp_truong.id, cp_qluc.id, cp_tac_huan.id ])
      expect(hash[cp_truong.id]).to   eq(bd("99"))
      expect(hash[cp_qluc.id]).to     eq(bd("105"))
      expect(hash[cp_tac_huan.id]).to eq(bd("500"))
    end

    it "does NOT include the pump meter (contact_point_id = nil) in loss_pool_consumption_by_cp" do
      expect(results[:loss_pool_consumption_by_cp].keys).not_to include(nil)
    end

    it "pump_loss_share(pump_station) = 96 × 1000 / 1704" do
      expect(calc.pump_loss_share(pump_station)).to eq(bd("96") * bd("1000") / bd("1704"))
    end

    it "returns BigDecimal for all numeric fields" do
      expect(results[:zone_supply_kw]).to be_a(BigDecimal)
      expect(results[:loss_pool_consumption_in_zone]).to be_a(BigDecimal)
      expect(results[:total_zone_loss]).to be_a(BigDecimal)
      results[:loss_pool_consumption_by_cp].each_value { |v| expect(v).to be_a(BigDecimal) }
    end
  end

  # ============================================================ Scenario B
  # Zone shared by DVA + DVB. supply 2000, no_loss 100, normal+public+pump = 1680
  # → B = 1680, A = 1900, C = 220.
  describe "Scenario B — zone-wide with no_loss + public meters" do
    let(:division)    { create(:organization, :division) }
    let(:main_meter)  { create(:main_meter, name: "Zone B") }
    let(:zone)        { main_meter.zone }
    let(:dva)         { create(:organization, level: :unit, parent: division, name: "DVA", zone: zone) }
    let(:dvb)         { create(:organization, level: :unit, parent: division, name: "DVB", zone: zone) }
    let(:period)      { create(:monthly_period, year: 2026, month: 4, unit_price: bd("2336.4")) }

    let!(:supply_reading) do
      create(:main_meter_reading,
             main_meter: main_meter, monthly_period: period,
             electricity_supply_kw: bd("2000"))
    end

    let!(:a1) { create(:contact_point, organization: dva, name: "A1", position: 1) }
    let!(:a2) { create(:contact_point, organization: dva, name: "A2", position: 2) }
    let!(:a3) { create(:contact_point, organization: dva, name: "A3", position: 3) }
    let!(:a4) { create(:contact_point, organization: dva, name: "A4 public", group_name: "public", position: 4) }
    let!(:b1) { create(:contact_point, organization: dvb, name: "B1", position: 1) }

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
    let!(:m_a3_no_loss) do
      m = create(:meter, :no_loss, organization: dva, contact_point: a3, name: "A3-CT1 no_loss")
      create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100)
      m
    end
    let!(:m_a4_public) do
      m = create(:meter, :public_meter, organization: dva, contact_point: a4, name: "A4-CT1 public")
      create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 200, consumption: 200)
      m
    end
    let!(:m_b1) do
      m = create(:meter, :normal, organization: dvb, contact_point: b1, name: "B1-CT1")
      create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100)
      m
    end

    let!(:pump_station) { create(:pump_station, zone: zone, name: "TB1") }
    let!(:m_pump) do
      m = create(:meter, :pump_station, organization: division, contact_point: nil, pump_station: pump_station, name: "TB1-CT1")
      create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500)
      m
    end
    let!(:pump_assignment) { create(:pump_station_assignment, pump_station: pump_station, organization: dva) }

    let(:tolerance) { bd("0.001") }
    let(:calc)      { described_class.new(zone: zone, monthly_period: period) }
    let(:results)   { calc.call }

    it "supply = 2000" do
      expect(results[:zone_supply_kw]).to eq(bd("2000"))
    end

    it "B = 1680 (sum: normal 800+50+30+100 + public 200 + pump 500; no_loss excluded)" do
      expect(results[:loss_pool_consumption_in_zone]).to eq(bd("1680"))
    end

    it "C = total_zone_loss = 220 (= 2000 - 100 - 1680)" do
      expect(results[:total_zone_loss]).to eq(bd("220"))
    end

    it "loss_pool_consumption_by_cp excludes the no_loss meter (a3) entirely" do
      hash = results[:loss_pool_consumption_by_cp]
      expect(hash.keys).to match_array([ a1.id, a2.id, a4.id, b1.id ])
      expect(hash).not_to have_key(a3.id)
    end

    it "loss_pool_consumption_by_cp[a2] sums both meters (50 + 30 = 80)" do
      expect(results[:loss_pool_consumption_by_cp][a2.id]).to eq(bd("80"))
    end

    it "loss_pool_consumption_by_cp includes public meter (a4 = 200) and cross-org CP (b1 = 100)" do
      hash = results[:loss_pool_consumption_by_cp]
      expect(hash[a4.id]).to eq(bd("200"))
      expect(hash[b1.id]).to eq(bd("100"))
    end

    it "pump_loss_share(TB1) = 220 × 500 / 1680 ≈ 65.476" do
      expected = bd("220") * bd("500") / bd("1680")
      expect(calc.pump_loss_share(pump_station)).to be_within(tolerance).of(expected)
    end
  end

  # ============================================================ Scenario C
  # Edge cases.
  describe "Scenario C — edge cases" do
    let(:division)    { create(:organization, :division) }
    let(:period)      { create(:monthly_period, year: 2026, month: 5, unit_price: bd("2336.4")) }

    describe "zone is nil" do
      let(:calc) { described_class.new(zone: nil, monthly_period: period) }

      it "returns nil supply" do
        expect(calc.call[:zone_supply_kw]).to be_nil
      end

      it "returns ZERO total_zone_loss" do
        expect(calc.call[:total_zone_loss]).to eq(bd("0"))
      end

      it "returns ZERO loss_pool_consumption_in_zone" do
        expect(calc.call[:loss_pool_consumption_in_zone]).to eq(bd("0"))
      end

      it "returns empty loss_pool_consumption_by_cp" do
        expect(calc.call[:loss_pool_consumption_by_cp]).to eq({})
      end

      it "returns ZERO pump_loss_share for any pump station" do
        ps = create(:pump_station, name: "Orphan PS")
        expect(calc.pump_loss_share(ps)).to eq(bd("0"))
      end
    end

    describe "zone present but no MainMeterReading" do
      let(:main_meter)   { create(:main_meter, name: "Empty zone") }
      let(:zone)         { main_meter.zone }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let(:calc)         { described_class.new(zone: zone, monthly_period: period) }

      it "returns nil supply (no reading)" do
        expect(calc.call[:zone_supply_kw]).to be_nil
      end

      it "returns ZERO total_zone_loss" do
        expect(calc.call[:total_zone_loss]).to eq(bd("0"))
      end
    end

    describe "B = 0 (zone has supply + no_loss meters but no normal/public/pump)" do
      let(:main_meter)   { create(:main_meter, name: "B0 zone") }
      let(:zone)         { main_meter.zone }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let!(:supply_reading) do
        create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
               electricity_supply_kw: bd("500"))
      end
      let!(:cp) { create(:contact_point, organization: organization, name: "CP no-loss only", position: 1) }
      let!(:m_no_loss) do
        m = create(:meter, :no_loss, organization: organization, contact_point: cp, name: "no_loss meter")
        create(:meter_reading, meter: m, monthly_period: period, reading_start: 0, reading_end: 50, consumption: 50)
        m
      end
      let(:calc) { described_class.new(zone: zone, monthly_period: period) }

      it "B = 0" do
        expect(calc.call[:loss_pool_consumption_in_zone]).to eq(bd("0"))
      end

      it "C = supply - no_loss - 0 = 450 (still positive, no_loss subtracted)" do
        expect(calc.call[:total_zone_loss]).to eq(bd("450"))
      end

      it "pump_loss_share returns ZERO (denominator B is 0)" do
        ps = create(:pump_station, zone: zone, name: "PS")
        expect(calc.pump_loss_share(ps)).to eq(bd("0"))
      end
    end

    describe "A < B → total_zone_loss clamps to 0" do
      let(:main_meter)   { create(:main_meter, name: "Tiny supply") }
      let(:zone)         { main_meter.zone }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let!(:supply_reading) do
        create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
               electricity_supply_kw: bd("100"))
      end
      let!(:cp) { create(:contact_point, organization: organization, name: "Big consumer", position: 1) }
      let!(:m) do
        meter = create(:meter, :normal, organization: organization, contact_point: cp, name: "M big")
        create(:meter_reading, meter: meter, monthly_period: period, reading_start: 0, reading_end: 999, consumption: 999)
        meter
      end
      let(:calc) { described_class.new(zone: zone, monthly_period: period) }

      it "clamps total_zone_loss to 0 (A=100 − B=999 = −899)" do
        expect(calc.call[:total_zone_loss]).to eq(bd("0"))
      end

      it "pump_loss_share returns ZERO when total_zone_loss is clamped" do
        ps = create(:pump_station, zone: zone, name: "PS")
        expect(calc.pump_loss_share(ps)).to eq(bd("0"))
      end

      it "returns a :negative_loss warning describing supply vs consumption" do
        warning = calc.call[:warnings].first
        expect(warning).to be_present
        expect(warning[:type]).to eq(:negative_loss)
        expect(warning[:supply_adjusted]).to eq(bd("100"))
        expect(warning[:total_consumption]).to eq(bd("999"))
        expect(warning[:difference]).to eq(bd("-899"))
        expect(warning[:message]).to include("100", "999")
      end
    end

    describe "supply >= consumption → no warnings" do
      let(:main_meter)   { create(:main_meter, name: "Healthy supply") }
      let(:zone)         { main_meter.zone }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let!(:supply_reading) do
        create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
               electricity_supply_kw: bd("2000"))
      end
      let!(:cp) { create(:contact_point, organization: organization, name: "CP", position: 1) }
      let!(:m) do
        meter = create(:meter, :normal, organization: organization, contact_point: cp, name: "M")
        create(:meter_reading, meter: meter, monthly_period: period, reading_start: 0, reading_end: 1500, consumption: 1500)
        meter
      end
      let(:calc) { described_class.new(zone: zone, monthly_period: period) }

      it "returns an empty warnings array" do
        expect(calc.call[:warnings]).to eq([])
      end
    end

    describe "zone has no supply (no MainMeterReading) → no warnings" do
      let(:zone)          { create(:zone, name: "No supply zone") }
      let!(:_main_meter)  { create(:main_meter, zone: zone, name: "MM no reading") }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let(:calc)          { described_class.new(zone: zone, monthly_period: period) }

      it "returns an empty warnings array (cannot compute diff without supply)" do
        expect(calc.call[:warnings]).to eq([])
      end
    end

    describe "pump station with no consumption" do
      let(:main_meter)   { create(:main_meter, name: "Zone") }
      let(:zone)         { main_meter.zone }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let!(:supply_reading) do
        create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
               electricity_supply_kw: bd("1000"))
      end
      let!(:cp) { create(:contact_point, organization: organization, name: "CP", position: 1) }
      let!(:m) do
        meter = create(:meter, :normal, organization: organization, contact_point: cp, name: "M")
        create(:meter_reading, meter: meter, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100)
        meter
      end
      let!(:pump_station) { create(:pump_station, zone: zone, name: "PS-empty") }
      let(:calc) { described_class.new(zone: zone, monthly_period: period) }

      it "returns ZERO pump_loss_share (no meters / no readings on pump)" do
        expect(calc.pump_loss_share(pump_station)).to eq(bd("0"))
      end
    end

    describe "zone with multiple MainMeters" do
      let(:zone)         { create(:zone, name: "Multi-MM zone") }
      let!(:mm1)         { create(:main_meter, zone: zone, name: "MM1") }
      let!(:mm2)         { create(:main_meter, zone: zone, name: "MM2") }
      let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
      let!(:r1) do
        create(:main_meter_reading, main_meter: mm1, monthly_period: period,
               electricity_supply_kw: bd("1200"))
      end
      let!(:r2) do
        create(:main_meter_reading, main_meter: mm2, monthly_period: period,
               electricity_supply_kw: bd("800"))
      end
      let(:calc) { described_class.new(zone: zone, monthly_period: period) }

      it "sums supply across all MainMeters in the zone (1200 + 800 = 2000)" do
        expect(calc.call[:zone_supply_kw]).to eq(bd("2000"))
      end
    end
  end

  # ============================================================ Scenario D
  # Pump station assigned ONLY to a ContactPointGroup (no Organization /
  # ContactPoint assignment). Verifies that the loss-pool zone resolution
  # follows the group → member CP → organization route so the pump meter
  # still participates in B and pump_loss_share.
  describe "Scenario D — ContactPointGroup-only pump assignment pulls pump into zone" do
    let(:division)    { create(:organization, :division) }
    let(:main_meter)  { create(:main_meter, name: "Zone D") }
    let(:zone)        { main_meter.zone }
    let(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
    let(:period)      { create(:monthly_period, year: 2026, month: 5, unit_price: bd("2336.4")) }

    let!(:supply_reading) do
      create(:main_meter_reading,
             main_meter: main_meter, monthly_period: period,
             electricity_supply_kw: bd("1000"))
    end

    let!(:cp1) { create(:contact_point, organization: organization, name: "CP1") }
    let!(:cp2) { create(:contact_point, organization: organization, name: "CP2") }

    let!(:meter_cp1) { create(:meter, :normal, organization: organization, contact_point: cp1, name: "M-CP1") }
    let!(:reading_cp1) do
      create(:meter_reading, meter: meter_cp1, monthly_period: period,
             reading_start: 0, reading_end: 200, consumption: 200)
    end

    let!(:pump_station) { create(:pump_station, zone: zone, name: "TB-D") }
    let!(:pump_meter) do
      create(:meter, :pump_station, organization: division, contact_point: nil,
             pump_station: pump_station, name: "M-Pump-D")
    end
    let!(:pump_reading) do
      create(:meter_reading, meter: pump_meter, monthly_period: period,
             reading_start: 0, reading_end: 600, consumption: 600)
    end

    # Pump is ONLY tied to the zone via a ContactPointGroup assignment.
    let!(:group) { create(:contact_point_group, organization: organization, name: "Nhom CP1-CP2") }
    let!(:mem_cp1) { create(:contact_point_group_membership, contact_point_group: group, contact_point: cp1) }
    let!(:mem_cp2) { create(:contact_point_group_membership, contact_point_group: group, contact_point: cp2) }
    let!(:assignment) do
      create(:pump_station_assignment, pump_station: pump_station, assignable: group)
    end

    let(:calc) { described_class.new(zone: zone, monthly_period: period) }

    it "loss pool B includes the pump meter (200 normal + 600 pump = 800)" do
      expect(calc.call[:loss_pool_consumption_in_zone]).to eq(bd("800"))
    end

    it "total_zone_loss C = 1000 − 0 − 800 = 200" do
      expect(calc.call[:total_zone_loss]).to eq(bd("200"))
    end

    it "pump_loss_share = C × pump consumption / B = 200 × 600 / 800" do
      expect(calc.pump_loss_share(pump_station)).to eq(bd("200") * bd("600") / bd("800"))
    end
  end

  # ============================================================ Memoization
  describe "memoization" do
    let(:division)     { create(:organization, :division) }
    let(:main_meter)   { create(:main_meter, name: "Memo zone") }
    let(:zone)         { main_meter.zone }
    let!(:organization) { create(:organization, level: :unit, parent: division, zone: zone) }
    let(:period)       { create(:monthly_period, year: 2026, month: 6, unit_price: bd("2336.4")) }
    let!(:supply_reading) do
      create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
             electricity_supply_kw: bd("1000"))
    end
    let(:calc) { described_class.new(zone: zone, monthly_period: period) }

    it "returns the same hash values across repeated calls" do
      first  = calc.call
      second = calc.call
      expect(second[:total_zone_loss]).to eq(first[:total_zone_loss])
      expect(second[:zone_supply_kw]).to  eq(first[:zone_supply_kw])
    end
  end
end
