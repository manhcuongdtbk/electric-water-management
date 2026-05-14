require "rails_helper"

# Direct unit specs for SummaryCalculator — the per-CP standard + deductions
# + usage + billing phase extracted from CalculationOrchestrator. Loss + pump
# results are injected as plain Hashes, so this spec does NOT need any Zone,
# MainMeter, PumpStation, or PumpStationAssignment fixtures — orchestrator
# integration is covered by calculation_orchestrator_spec.rb.
RSpec.describe SummaryCalculator do
  def bd(value) = BigDecimal(value.to_s)

  let(:water_pump_rate) { bd("9.45") }
  let(:savings_rate)    { bd("0.05") }
  let(:div_public_rate) { bd("0.10") }
  let(:unit_public_rate) { bd("0.02") }
  let(:unit_price)      { bd("2336.4") }

  let_it_be(:division)     { create(:organization, :division) }
  let_it_be(:organization) { create(:organization, level: :unit, parent: division) }
  let_it_be(:period)       { create(:monthly_period, year: 2026, month: 2, unit_price: BigDecimal("2336.4")) }

  let_it_be(:rank_quota1) { create(:rank_quota, rank_group: 1, rank_name: "3*/4*", quota_kw: BigDecimal("115")) }
  let_it_be(:rank_quota2) { create(:rank_quota, rank_group: 2, rank_name: "1*/2*", quota_kw: BigDecimal("38")) }

  let_it_be(:cp_a) { create(:contact_point, organization: organization, name: "CP A", position: 1) }
  let_it_be(:cp_b) { create(:contact_point, organization: organization, name: "CP B", position: 2) }

  let_it_be(:personnel_a) do
    create(:personnel, contact_point: cp_a, monthly_period: period,
                       rank1_count: 1, rank2_count: 0, rank3_count: 0,
                       rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)
  end
  let_it_be(:personnel_b) do
    create(:personnel, contact_point: cp_b, monthly_period: period,
                       rank1_count: 0, rank2_count: 2, rank3_count: 0,
                       rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)
  end

  let_it_be(:meter_a) { create(:meter, :normal, organization: organization, contact_point: cp_a, name: "M-A") }
  let_it_be(:meter_b) { create(:meter, :normal, organization: organization, contact_point: cp_b, name: "M-B") }

  let_it_be(:reading_a) { create(:meter_reading, meter: meter_a, monthly_period: period, reading_start: 0, reading_end: 100, consumption: 100) }
  let_it_be(:reading_b) { create(:meter_reading, meter: meter_b, monthly_period: period, reading_start: 0, reading_end: 200, consumption: 200) }

  let!(:division_config) do
    create(:unit_config, organization: division, monthly_period: period,
                         savings_rate: savings_rate, division_public_rate: div_public_rate,
                         unit_public_rate: nil)
  end
  let!(:unit_config) do
    create(:unit_config, organization: organization, monthly_period: period,
                         savings_rate: nil, division_public_rate: nil,
                         unit_public_rate: unit_public_rate)
  end

  # Injected results — Hashes matching LossCalculator + PumpAllocationCalculator
  # public interfaces. Zone-wide loss of 60 kW spread over 300 kW pool; CP A
  # gets 60 × 100/300 = 20, CP B gets 60 × 200/300 = 40.
  let(:loss_results) do
    {
      total_zone_loss:               bd("60"),
      loss_pool_consumption_in_zone: bd("300"),
      loss_pool_consumption_by_cp:   { cp_a.id => bd("100"), cp_b.id => bd("200") },
      zone_supply_kw:                bd("360")
    }
  end

  let(:pump_results) do
    {
      allocations_by_cp:         { cp_a.id => bd("50"), cp_b.id => bd("80") },
      allocations_by_assignment: {},
      total_pool_kw:             bd("130")
    }
  end

  let(:contact_points) { [ cp_a, cp_b ] }

  subject(:summary) do
    described_class.new(
      organization:   organization,
      monthly_period: period,
      loss_results:   loss_results,
      pump_results:   pump_results
    )
  end

  let(:results) { summary.compute(contact_points) }
  def row_for(cp) = results.find { |r| r[:contact_point_id] == cp.id }

  describe "#compute" do
    it "returns one row per contact point" do
      expect(results.size).to eq(2)
    end

    it "preserves contact_point object in row Hash" do
      expect(row_for(cp_a)[:contact_point]).to eq(cp_a)
      expect(row_for(cp_b)[:contact_point]).to eq(cp_b)
    end

    it "sets monthly_period_id from injected period" do
      expect(row_for(cp_a)[:monthly_period_id]).to eq(period.id)
    end
  end

  describe "standard row (rank kW + water pump standard)" do
    it "computes rank1_kw from rank1_count × rank_quotas[1]" do
      expect(row_for(cp_a)[:rank1_kw]).to eq(bd("115"))
    end

    it "computes rank2_kw from rank2_count × rank_quotas[2]" do
      expect(row_for(cp_b)[:rank2_kw]).to eq(bd("76"))
    end

    it "sets unused rank slots to 0" do
      expect(row_for(cp_a)[:rank2_kw]).to eq(bd("0"))
      expect(row_for(cp_b)[:rank1_kw]).to eq(bd("0"))
      (3..7).each do |i|
        expect(row_for(cp_a)[:"rank#{i}_kw"]).to eq(bd("0"))
      end
    end

    it "water_pump_standard_kw = total_personnel × 9.45" do
      expect(row_for(cp_a)[:water_pump_standard_kw]).to eq(bd("1") * water_pump_rate)
      expect(row_for(cp_b)[:water_pump_standard_kw]).to eq(bd("2") * water_pump_rate)
    end

    it "total_standard_kw = sum of ranks + water_pump_standard" do
      expect(row_for(cp_a)[:total_standard_kw]).to eq(bd("115") + bd("1") * water_pump_rate)
      expect(row_for(cp_b)[:total_standard_kw]).to eq(bd("76") + bd("2") * water_pump_rate)
    end
  end

  describe "deductions" do
    it "savings = total_standard × savings_rate (from division UnitConfig)" do
      expected = row_for(cp_a)[:total_standard_kw] * savings_rate
      expect(row_for(cp_a)[:savings_deduction_kw]).to eq(expected)
    end

    it "division_public = total_standard × division_public_rate (from division UnitConfig)" do
      expected = row_for(cp_a)[:total_standard_kw] * div_public_rate
      expect(row_for(cp_a)[:division_public_deduction_kw]).to eq(expected)
    end

    it "unit_public = total_standard × unit_public_rate (from unit UnitConfig)" do
      expected = row_for(cp_a)[:total_standard_kw] * unit_public_rate
      expect(row_for(cp_a)[:unit_public_deduction_kw]).to eq(expected)
    end

    it "loss = total_zone_loss × cp_consumption / loss_pool_total (from injected loss_results)" do
      expect(row_for(cp_a)[:loss_deduction_kw]).to eq(bd("60") * bd("100") / bd("300"))
      expect(row_for(cp_b)[:loss_deduction_kw]).to eq(bd("60") * bd("200") / bd("300"))
    end

    it "loss = 0 when CP has no entry in loss_pool_consumption_by_cp" do
      orphan_cp = create(:contact_point, organization: organization, name: "Orphan", position: 3)
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   loss_results,
        pump_results:   pump_results
      ).compute([ orphan_cp ])
      expect(result.first[:loss_deduction_kw]).to eq(bd("0"))
    end

    it "loss = 0 when total_zone_loss is 0" do
      zero_loss = loss_results.merge(total_zone_loss: bd("0"))
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   zero_loss,
        pump_results:   pump_results
      ).compute(contact_points)
      expect(result.first[:loss_deduction_kw]).to eq(bd("0"))
    end

    it "loss = 0 when loss_pool_consumption_in_zone is 0" do
      zero_pool = loss_results.merge(loss_pool_consumption_in_zone: bd("0"))
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   zero_pool,
        pump_results:   pump_results
      ).compute(contact_points)
      expect(result.first[:loss_deduction_kw]).to eq(bd("0"))
    end

    context "other_deduction" do
      it "fixed_kw — returns the raw value regardless of personnel" do
        create(:contact_point_other_deduction,
               contact_point: cp_a, monthly_period: period,
               other_type: :fixed_kw, other_value: bd("17.5"))
        expect(row_for(cp_a)[:other_deduction_kw]).to eq(bd("17.5"))
      end

      it "factor_per_person — returns value × personnel_count" do
        create(:contact_point_other_deduction,
               contact_point: cp_b, monthly_period: period,
               other_type: :factor_per_person, other_value: bd("3"))
        expect(row_for(cp_b)[:other_deduction_kw]).to eq(bd("3") * bd("2"))
      end

      it "= 0 when no record exists for the CP" do
        expect(row_for(cp_a)[:other_deduction_kw]).to eq(bd("0"))
      end
    end

    it "total_deduction_kw = sum of all 5 deduction components" do
      r = row_for(cp_a)
      expected = r[:savings_deduction_kw] + r[:loss_deduction_kw] +
                 r[:division_public_deduction_kw] + r[:unit_public_deduction_kw] +
                 r[:other_deduction_kw]
      expect(r[:total_deduction_kw]).to eq(expected)
    end

    it "remaining_standard_kw = total_standard − total_deduction" do
      r = row_for(cp_a)
      expect(r[:remaining_standard_kw]).to eq(r[:total_standard_kw] - r[:total_deduction_kw])
    end
  end

  describe "usage" do
    it "meter_usage_kw = sum of normal meter readings for the CP" do
      expect(row_for(cp_a)[:meter_usage_kw]).to eq(bd("100"))
      expect(row_for(cp_b)[:meter_usage_kw]).to eq(bd("200"))
    end

    it "water_pump_actual_kw = pump_results[:allocations_by_cp][cp_id]" do
      expect(row_for(cp_a)[:water_pump_actual_kw]).to eq(bd("50"))
      expect(row_for(cp_b)[:water_pump_actual_kw]).to eq(bd("80"))
    end

    it "water_pump_actual_kw = 0 when CP has no entry in allocations_by_cp" do
      orphan_cp = create(:contact_point, organization: organization, name: "Orphan", position: 3)
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   loss_results,
        pump_results:   pump_results
      ).compute([ orphan_cp ])
      expect(result.first[:water_pump_actual_kw]).to eq(bd("0"))
    end

    it "total_usage_kw = meter_usage + water_pump_actual" do
      expect(row_for(cp_a)[:total_usage_kw]).to eq(bd("100") + bd("50"))
      expect(row_for(cp_b)[:total_usage_kw]).to eq(bd("200") + bd("80"))
    end

    it "meter_usage filter: meter_type = normal (no_loss meters of type normal are still included)" do
      no_loss_meter = create(:meter, :normal, organization: organization,
                                              contact_point: cp_a, name: "M-A-no-loss", no_loss: true)
      create(:meter_reading, meter: no_loss_meter, monthly_period: period,
                             reading_start: 0, reading_end: 25, consumption: 25)
      expect(row_for(cp_a)[:meter_usage_kw]).to eq(bd("125"))
    end
  end

  describe "billing" do
    it "over_under_kw = total_usage − remaining_standard" do
      r = row_for(cp_a)
      expect(r[:over_under_kw]).to eq(r[:total_usage_kw] - r[:remaining_standard_kw])
    end

    it "unit_price = monthly_period.unit_price" do
      expect(row_for(cp_a)[:unit_price]).to eq(unit_price)
    end

    it "total_amount = over_under × unit_price" do
      r = row_for(cp_a)
      expect(r[:total_amount]).to eq(r[:over_under_kw] * unit_price)
    end
  end

  describe "edge cases" do
    it "no personnel → all rank_kw = 0 and total_standard = 0" do
      lonely_cp = create(:contact_point, organization: organization, name: "Lonely", position: 9)
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   loss_results,
        pump_results:   pump_results
      ).compute([ lonely_cp ])
      row = result.first
      (1..7).each { |i| expect(row[:"rank#{i}_kw"]).to eq(bd("0")) }
      expect(row[:total_personnel]).to eq(0)
      expect(row[:water_pump_standard_kw]).to eq(bd("0"))
      expect(row[:total_standard_kw]).to eq(bd("0"))
    end

    it "no meter readings → meter_usage_kw = 0" do
      bare_cp = create(:contact_point, organization: organization, name: "Bare", position: 10)
      create(:personnel, contact_point: bare_cp, monthly_period: period,
                         rank1_count: 1, rank2_count: 0, rank3_count: 0,
                         rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   loss_results,
        pump_results:   pump_results
      ).compute([ bare_cp ])
      expect(result.first[:meter_usage_kw]).to eq(bd("0"))
    end

    it "no UnitConfig for division or unit → all rates resolve to 0" do
      unit_config.destroy
      division_config.destroy
      r = row_for(cp_a)
      expect(r[:savings_deduction_kw]).to eq(bd("0"))
      expect(r[:division_public_deduction_kw]).to eq(bd("0"))
      expect(r[:unit_public_deduction_kw]).to eq(bd("0"))
    end

    it "config lookup — savings_rate from division UnitConfig, unit_public_rate from unit UnitConfig" do
      # Mutate only the unit UnitConfig — savings_rate stays sourced from division config.
      unit_config.update!(unit_public_rate: bd("0.99"))
      result = described_class.new(
        organization:   organization,
        monthly_period: period,
        loss_results:   loss_results,
        pump_results:   pump_results
      ).compute(contact_points)
      r = result.find { |row| row[:contact_point_id] == cp_a.id }
      expect(r[:unit_public_deduction_kw]).to eq(r[:total_standard_kw] * bd("0.99"))
      expect(r[:savings_deduction_kw]).to eq(r[:total_standard_kw] * savings_rate)
    end
  end
end
