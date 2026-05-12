require "rails_helper"

RSpec.describe MonthlyCalculation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "validations" do
    subject { build(:monthly_calculation) }

    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:monthly_period_id) }
    it { is_expected.to validate_numericality_of(:total_personnel).only_integer.is_greater_than_or_equal_to(0) }

    %i[
      rank1_kw rank2_kw rank3_kw rank4_kw rank5_kw rank6_kw rank7_kw
      water_pump_standard_kw water_pump_actual_kw
      total_standard_kw total_usage_kw total_deduction_kw remaining_standard_kw
      meter_usage_kw savings_deduction_kw loss_deduction_kw
      division_public_deduction_kw unit_public_deduction_kw other_deduction_kw
      unit_price total_amount
    ].each do |col|
      it { is_expected.to validate_numericality_of(col) }
    end
  end

  describe "scopes" do
    it ".by_organization filters by contact_point's organization" do
      org = create(:organization)
      cp = create(:contact_point, organization: org)
      c1 = create(:monthly_calculation, contact_point: cp)
      c2 = create(:monthly_calculation)
      expect(MonthlyCalculation.by_organization(org.id)).to include(c1)
      expect(MonthlyCalculation.by_organization(org.id)).not_to include(c2)
    end

    describe ".excluding_communal_cps" do
      let(:org) { create(:organization) }
      let(:cp_residential_a) { create(:contact_point, :residential, organization: org, name: "Residential A") }
      let(:cp_residential_b) { create(:contact_point, :residential, organization: org, name: "Residential B") }
      let(:cp_communal)      { create(:contact_point, :communal,    organization: org, name: "Communal") }

      before do
        @calc_residential_a = create(:monthly_calculation, contact_point: cp_residential_a)
        @calc_residential_b = create(:monthly_calculation, contact_point: cp_residential_b)
        @calc_communal      = create(:monthly_calculation, contact_point: cp_communal)
      end

      it "keeps CPs flagged as residential" do
        expect(MonthlyCalculation.excluding_communal_cps)
          .to include(@calc_residential_a, @calc_residential_b)
      end

      it "excludes CPs flagged as communal" do
        expect(MonthlyCalculation.excluding_communal_cps).not_to include(@calc_communal)
      end

      it "is a no-op when no communal CP exists" do
        ContactPoint.communal.destroy_all
        expect(MonthlyCalculation.excluding_communal_cps.count)
          .to eq(MonthlyCalculation.count)
      end
    end
  end

  describe "#rank_standard_total_kw" do
    it "sums all rank kW columns" do
      calc = build(:monthly_calculation,
                   rank1_kw: 1140, rank2_kw: 2200, rank3_kw: 3050,
                   rank4_kw: 2600, rank5_kw: 0, rank6_kw: 330, rank7_kw: 0)
      expect(calc.rank_standard_total_kw).to eq(9320)
    end
  end
end
