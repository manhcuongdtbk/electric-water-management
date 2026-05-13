require "rails_helper"

# Standalone, zone-wide pump allocation calculator. Each context wires the
# minimum data needed for its scenario — no shared rich fixture.
#
# When no MainMeter / MainMeterReading exists, LossCalculator returns
# zone_supply_kw = nil → total_zone_loss = 0 → pump_loss_share = 0. So pump
# pool == raw meter consumption in those contexts. One context explicitly
# verifies the loss-share path via an injected LossCalculator.
RSpec.describe PumpAllocationCalculator do
  def bd(value) = BigDecimal(value.to_s)

  let(:tolerance) { bd("0.01") }
  let(:period)    { create(:monthly_period, year: 2026, month: 4) }
  let(:zone)      { create(:zone, name: "Khu vực A") }

  def make_personnel(contact_point:, rank1: 0, rank2: 0, rank3: 0, rank4: 0,
                     rank5: 0, rank6: 0, rank7: 0)
    create(:personnel, contact_point: contact_point, monthly_period: period,
           rank1_count: rank1, rank2_count: rank2, rank3_count: rank3,
           rank4_count: rank4, rank5_count: rank5, rank6_count: rank6,
           rank7_count: rank7)
  end

  def make_pump_meter(pump_station:, org:, consumption:)
    m = create(:meter, :pump_station, organization: org, contact_point: nil,
               pump_station: pump_station)
    create(:meter_reading, meter: m, monthly_period: period,
           reading_start: 0, reading_end: consumption, consumption: consumption)
    m
  end

  describe "#call" do
    context "when zone is nil" do
      subject(:result) { described_class.new(zone: nil, monthly_period: period).call }

      it "returns empty allocations and zero pool" do
        expect(result[:allocations_by_cp]).to eq({})
        expect(result[:allocations_by_assignment]).to eq([])
        expect(result[:total_pool_kw]).to eq(bd("0"))
      end
    end

    # Scenario: 1 pump, 2 unit-orgs, with a CP fixed slot, two org variable
    # slots, and a WorkGroup variable slot. Mirrors the integration setup so
    # the maths are familiar:
    #
    #   pool = 1000 (no MainMeter → loss = 0)
    #   A1 fixed 30%               = 300
    #   Variable pool 70%          = 700
    #     headcount DVA 6 + DVB 5 + WG 2 = 13
    #     DVA → 700 × 6/13 ≈ 323.077 → split by personnel within DVA:
    #       A1 ← 323.077 × 2/6 ≈ 107.692
    #       A2 ← 323.077 × 3/6 ≈ 161.538
    #       A3 ← 323.077 × 1/6 ≈ 53.846
    #       A4 ← 0 (no personnel)
    #     DVB → 700 × 5/13 ≈ 269.231 → all to B1
    #     WG  → 700 × 2/13 ≈ 107.692 (assignment row only, no CP allocation)
    #
    #   A1 total = 300 + 107.692 ≈ 407.692
    context "one pump with mixed CP / Org / WorkGroup assignments" do
      let(:division) { create(:organization, :division) }
      let(:dva)      { create(:organization, level: :unit, parent: division, name: "DVA", zone: zone) }
      let(:dvb)      { create(:organization, level: :unit, parent: division, name: "DVB", zone: zone) }

      let!(:a1) { create(:contact_point, organization: dva, name: "A1", position: 1) }
      let!(:a2) { create(:contact_point, organization: dva, name: "A2", position: 2) }
      let!(:a3) { create(:contact_point, organization: dva, name: "A3", position: 3) }
      let!(:a4) { create(:contact_point, organization: dva, name: "A4", position: 4) }
      let!(:b1) { create(:contact_point, organization: dvb, name: "B1", position: 1) }

      let!(:p_a1) { make_personnel(contact_point: a1, rank1: 2) }
      let!(:p_a2) { make_personnel(contact_point: a2, rank7: 3) }
      let!(:p_a3) { make_personnel(contact_point: a3, rank4: 1) }
      let!(:p_b1) { make_personnel(contact_point: b1, rank7: 5) }
      # A4: no personnel row

      let!(:pump_station) { create(:pump_station, zone: zone, name: "TB1") }
      let!(:m_pump)       { make_pump_meter(pump_station: pump_station, org: division, consumption: bd("1000")) }

      let!(:work_group) { create(:work_group, owner_organization: dva, name: "Tho xay", personnel_count: 2, position: 0) }

      let!(:asg_a1)  { create(:pump_station_assignment, pump_station: pump_station, assignable: a1, fixed_pump_percentage: 30) }
      let!(:asg_dva) { create(:pump_station_assignment, pump_station: pump_station, assignable: dva) }
      let!(:asg_dvb) { create(:pump_station_assignment, pump_station: pump_station, assignable: dvb) }
      let!(:asg_wg)  { create(:pump_station_assignment, pump_station: pump_station, assignable: work_group) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      let(:pool)          { bd("1000") }
      let(:variable_pool) { pool * bd("0.70") }

      it "stacks CP fixed slot AND parent-org variable slice on the same CP" do
        dva_share   = variable_pool * bd("6") / bd("13")
        a1_from_dva = dva_share * bd("2") / bd("6")
        expect(result[:allocations_by_cp][a1.id]).to be_within(tolerance).of(pool * bd("0.30") + a1_from_dva)
      end

      it "drills DVA variable share across CPs by personnel ratio" do
        dva_share = variable_pool * bd("6") / bd("13")
        expect(result[:allocations_by_cp][a2.id]).to be_within(tolerance).of(dva_share * bd("3") / bd("6"))
        expect(result[:allocations_by_cp][a3.id]).to be_within(tolerance).of(dva_share * bd("1") / bd("6"))
        expect(result[:allocations_by_cp]).not_to have_key(a4.id) # 0 personnel → skipped
      end

      it "routes DVB's full 5/13 share to its single CP" do
        expect(result[:allocations_by_cp][b1.id]).to be_within(tolerance).of(variable_pool * bd("5") / bd("13"))
      end

      it "lists every assignment in allocations_by_assignment" do
        types = result[:allocations_by_assignment].map { |r| r[:assignable_type] }.tally
        expect(types).to eq("ContactPoint" => 1, "Organization" => 2, "WorkGroup" => 1)
      end

      it "reports total_pool_kw as raw pool sum" do
        expect(result[:total_pool_kw]).to eq(pool)
      end

      it "Σ assignment rows ≈ pool (conservation across fixed + variable)" do
        total = result[:allocations_by_assignment].sum { |r| r[:kw] }
        expect(total).to be_within(bd("0.01")).of(pool)
      end
    end

    context "ContactPointGroup with 2 member CPs (3:1 personnel)" do
      let(:org) { create(:organization, level: :unit, zone: zone) }
      let!(:cp1) { create(:contact_point, organization: org, name: "CP1") }
      let!(:cp2) { create(:contact_point, organization: org, name: "CP2") }
      let!(:p1)  { make_personnel(contact_point: cp1, rank1: 3) }
      let!(:p2)  { make_personnel(contact_point: cp2, rank1: 1) }
      let!(:cpg) { create(:contact_point_group, organization: org, name: "Grp") }
      let!(:m1)  { create(:contact_point_group_membership, contact_point_group: cpg, contact_point: cp1) }
      let!(:m2)  { create(:contact_point_group_membership, contact_point_group: cpg, contact_point: cp2) }

      let!(:ps)  { create(:pump_station, zone: zone, name: "TB") }
      let!(:m_p) { make_pump_meter(pump_station: ps, org: org, consumption: bd("400")) }
      let!(:asg) { create(:pump_station_assignment, pump_station: ps, assignable: cpg, fixed_pump_percentage: 100) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "drills the group's share across member CPs by personnel ratio" do
        expect(result[:allocations_by_cp][cp1.id]).to be_within(tolerance).of(bd("300"))
        expect(result[:allocations_by_cp][cp2.id]).to be_within(tolerance).of(bd("100"))
      end

      it "reports an assignment row labelled ContactPointGroup with summed personnel" do
        row = result[:allocations_by_assignment].find { |r| r[:assignable_type] == "ContactPointGroup" }
        expect(row[:assignable_id]).to eq(cpg.id)
        expect(row[:personnel]).to eq(4)
        expect(row[:kw]).to be_within(tolerance).of(bd("400"))
      end
    end

    context "ContactPoint direct assignment" do
      let(:org)  { create(:organization, level: :unit, zone: zone) }
      let!(:cp)  { create(:contact_point, organization: org) }
      let!(:pp)  { make_personnel(contact_point: cp, rank1: 5) }
      let!(:ps)  { create(:pump_station, zone: zone) }
      let!(:m)   { make_pump_meter(pump_station: ps, org: org, consumption: bd("200")) }
      let!(:asg) { create(:pump_station_assignment, pump_station: ps, assignable: cp, fixed_pump_percentage: 100) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "credits the CP directly in allocations_by_cp" do
        expect(result[:allocations_by_cp][cp.id]).to be_within(tolerance).of(bd("200"))
      end

      it "reports an assignment row labelled ContactPoint" do
        row = result[:allocations_by_assignment].find { |r| r[:assignable_type] == "ContactPoint" }
        expect(row[:assignable_id]).to eq(cp.id)
        expect(row[:kw]).to be_within(tolerance).of(bd("200"))
      end
    end

    context "WorkGroup assignment alongside Organization" do
      let(:org)   { create(:organization, level: :unit, zone: zone) }
      let!(:cp)   { create(:contact_point, organization: org) }
      let!(:pp)   { make_personnel(contact_point: cp, rank1: 3) }
      let!(:wg)   { create(:work_group, owner_organization: org, personnel_count: 2) }
      let!(:ps)   { create(:pump_station, zone: zone) }
      let!(:m_ps) { make_pump_meter(pump_station: ps, org: org, consumption: bd("100")) }
      let!(:asg_org) { create(:pump_station_assignment, pump_station: ps, assignable: org) }
      let!(:asg_wg)  { create(:pump_station_assignment, pump_station: ps, assignable: wg) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "WorkGroup share appears in allocations_by_assignment" do
        # Total variable headcount: org 3 + wg 2 = 5. WG gets 2/5 × 100 = 40.
        wg_row = result[:allocations_by_assignment].find { |r| r[:assignable_type] == "WorkGroup" }
        expect(wg_row[:kw]).to be_within(tolerance).of(bd("40"))
      end

      it "WorkGroup share does NOT appear in allocations_by_cp" do
        expect(result[:allocations_by_cp].keys).to contain_exactly(cp.id)
      end
    end

    context "multiple pump stations accumulate on the same CP" do
      let(:org) { create(:organization, level: :unit, zone: zone) }
      let!(:cp) { create(:contact_point, organization: org) }
      let!(:pp) { make_personnel(contact_point: cp, rank1: 1) }
      let!(:ps1) { create(:pump_station, zone: zone, name: "TB1") }
      let!(:ps2) { create(:pump_station, zone: zone, name: "TB2") }
      let!(:m1) { make_pump_meter(pump_station: ps1, org: org, consumption: bd("60")) }
      let!(:m2) { make_pump_meter(pump_station: ps2, org: org, consumption: bd("40")) }
      # Variable Org assignment on each pump — full pool drills to the only CP.
      let!(:asg1) { create(:pump_station_assignment, pump_station: ps1, assignable: org) }
      let!(:asg2) { create(:pump_station_assignment, pump_station: ps2, assignable: org) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "accumulates per-CP kW across pump stations" do
        expect(result[:allocations_by_cp][cp.id]).to be_within(tolerance).of(bd("100"))
      end

      it "sums total_pool_kw across pump stations" do
        expect(result[:total_pool_kw]).to be_within(tolerance).of(bd("100"))
      end

      it "lists one assignment row per pump-station assignment" do
        expect(result[:allocations_by_assignment].size).to eq(2)
      end
    end

    context "sum_fixed_pct > 100 (clamped to variable_pct = 0)" do
      let(:org) { create(:organization, level: :unit, zone: zone) }
      let!(:cp1) { create(:contact_point, organization: org) }
      let!(:cp2) { create(:contact_point, organization: org) }
      let!(:p1) { make_personnel(contact_point: cp1, rank1: 1) }
      let!(:p2) { make_personnel(contact_point: cp2, rank1: 1) }
      let!(:ps) { create(:pump_station, zone: zone) }
      let!(:m)  { make_pump_meter(pump_station: ps, org: org, consumption: bd("100")) }
      let!(:asg_f1) { create(:pump_station_assignment, pump_station: ps, assignable: cp1, fixed_pump_percentage: 80) }
      let!(:asg_f2) do
        # Bypass zone-validation that caps sum_fixed at 100 — we're testing
        # the calculator's clamp behaviour under intentionally bad data.
        build(:pump_station_assignment, pump_station: ps, assignable: cp2, fixed_pump_percentage: 50)
          .save!(validate: false)
      end
      let!(:asg_var) { create(:pump_station_assignment, pump_station: ps, assignable: org) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "variable assignment receives 0" do
        org_row = result[:allocations_by_assignment].find { |r| r[:assignable_type] == "Organization" }
        expect(org_row[:kw]).to eq(bd("0"))
      end

      it "fixed assignments still receive their raw percentage" do
        cp1_row = result[:allocations_by_assignment].find { |r| r[:assignable_id] == cp1.id }
        cp2_row = result[:allocations_by_assignment].find { |r| r[:assignable_id] == cp2.id }
        expect(cp1_row[:kw]).to be_within(tolerance).of(bd("80"))
        expect(cp2_row[:kw]).to be_within(tolerance).of(bd("50"))
      end
    end

    context "fixed_pump_percentage = 0" do
      let(:org) { create(:organization, level: :unit, zone: zone) }
      let!(:cp1) { create(:contact_point, organization: org) }
      let!(:cp2) { create(:contact_point, organization: org) }
      let!(:p1) { make_personnel(contact_point: cp1, rank1: 2) }
      let!(:p2) { make_personnel(contact_point: cp2, rank1: 3) }
      let!(:ps) { create(:pump_station, zone: zone) }
      let!(:m)  { make_pump_meter(pump_station: ps, org: org, consumption: bd("100")) }
      let!(:asg_zero) { create(:pump_station_assignment, pump_station: ps, assignable: cp1, fixed_pump_percentage: 0) }
      let!(:asg_var)  { create(:pump_station_assignment, pump_station: ps, assignable: cp2) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "fixed 0% assignment receives 0 and does NOT join the variable pool" do
        zero_row = result[:allocations_by_assignment].find { |r| r[:assignable_id] == cp1.id }
        var_row  = result[:allocations_by_assignment].find { |r| r[:assignable_id] == cp2.id }
        expect(zero_row[:kw]).to eq(bd("0"))
        # cp2 sweeps the entire variable pool (1.0 × 100% × 3/3).
        expect(var_row[:kw]).to be_within(tolerance).of(bd("100"))
      end

      it "cp1 has no entry in allocations_by_cp" do
        expect(result[:allocations_by_cp].keys).to contain_exactly(cp2.id)
      end
    end

    context "variable pool with zero total headcount" do
      let(:org)  { create(:organization, level: :unit, zone: zone) }
      let!(:cp)  { create(:contact_point, organization: org) }
      # No personnel record → headcount = 0
      let!(:ps)  { create(:pump_station, zone: zone) }
      let!(:m)   { make_pump_meter(pump_station: ps, org: org, consumption: bd("100")) }
      let!(:asg) { create(:pump_station_assignment, pump_station: ps, assignable: org) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "variable assignment receives 0 with no CP allocation" do
        org_row = result[:allocations_by_assignment].find { |r| r[:assignable_type] == "Organization" }
        expect(org_row[:kw]).to eq(bd("0"))
        expect(result[:allocations_by_cp]).to be_empty
      end
    end

    context "pump station with no meter readings" do
      let(:org)  { create(:organization, level: :unit, zone: zone) }
      let!(:cp)  { create(:contact_point, organization: org) }
      let!(:pp)  { make_personnel(contact_point: cp, rank1: 1) }
      let!(:ps)  { create(:pump_station, zone: zone) }
      let!(:m)   { create(:meter, :pump_station, organization: org, contact_point: nil, pump_station: ps) }
      # No MeterReading → consumption = 0
      let!(:asg) { create(:pump_station_assignment, pump_station: ps, assignable: org) }

      subject(:result) { described_class.new(zone: zone, monthly_period: period).call }

      it "skips the station entirely — no assignment rows, no CP allocation, pool = 0" do
        expect(result[:total_pool_kw]).to eq(bd("0"))
        expect(result[:allocations_by_assignment]).to be_empty
        expect(result[:allocations_by_cp]).to be_empty
      end
    end

    context "injected LossCalculator inflates the pump pool" do
      let(:org)  { create(:organization, level: :unit, zone: zone) }
      let!(:cp)  { create(:contact_point, organization: org) }
      let!(:pp)  { make_personnel(contact_point: cp, rank1: 1) }
      let!(:ps)  { create(:pump_station, zone: zone) }
      let!(:m)   { make_pump_meter(pump_station: ps, org: org, consumption: bd("100")) }
      let!(:asg) { create(:pump_station_assignment, pump_station: ps, assignable: cp, fixed_pump_percentage: 100) }

      it "uses the injected loss_calculator to compute pump_loss_share" do
        loss_calc = LossCalculator.new(zone: zone, monthly_period: period)
        expect(loss_calc).to receive(:pump_loss_share).with(ps).and_return(bd("50"))

        result = described_class.new(zone: zone, monthly_period: period, loss_calculator: loss_calc).call

        expect(result[:total_pool_kw]).to be_within(tolerance).of(bd("150"))
        expect(result[:allocations_by_cp][cp.id]).to be_within(tolerance).of(bd("150"))
      end
    end
  end
end
