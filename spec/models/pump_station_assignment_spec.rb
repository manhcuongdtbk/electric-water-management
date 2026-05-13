require "rails_helper"

RSpec.describe PumpStationAssignment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:pump_station) }
    it { is_expected.to belong_to(:assignable) }
  end

  it "has paper_trail enabled" do
    expect(PumpStationAssignment).to respond_to(:paper_trail)
    expect(PumpStationAssignment.new).to respond_to(:paper_trail)
  end

  describe "validations" do
    subject { build(:pump_station_assignment) }

    it { is_expected.to validate_inclusion_of(:assignable_type).in_array(%w[Organization ContactPoint WorkGroup ContactPointGroup]) }

    it "prevents duplicate assignment for same pump and same assignable" do
      ps  = create(:pump_station)
      unit = create(:organization, :unit)
      create(:pump_station_assignment, pump_station: ps, assignable: unit)
      dup = build(:pump_station_assignment, pump_station: ps, assignable: unit)
      expect(dup).not_to be_valid
    end

    it "allows same Organization id and ContactPoint id on same pump (different types)" do
      ps   = create(:pump_station)
      unit = create(:organization, :unit)
      cp   = create(:contact_point, organization: unit)
      # Force the ContactPoint id to equal the Organization id is impossible
      # in this scenario, but the scope on assignable_type means the two coexist
      # regardless.
      create(:pump_station_assignment, pump_station: ps, assignable: unit)
      asg = build(:pump_station_assignment, pump_station: ps, assignable: cp)
      expect(asg).to be_valid
    end

    it { is_expected.to validate_numericality_of(:fixed_pump_percentage)
                          .is_greater_than_or_equal_to(0)
                          .is_less_than_or_equal_to(100)
                          .allow_nil }

    it "rejects division-level Organization as assignable" do
      ps  = create(:pump_station)
      div = create(:organization, :division)
      asg = build(:pump_station_assignment, pump_station: ps, assignable: div)
      expect(asg).not_to be_valid
      expect(asg.errors[:assignable]).to be_present
    end

    it "accepts unit-level Organization as assignable" do
      ps   = create(:pump_station)
      unit = create(:organization, :unit)
      asg  = build(:pump_station_assignment, pump_station: ps, assignable: unit)
      expect(asg).to be_valid
    end

    it "accepts ContactPoint whose organization is unit-level" do
      ps  = create(:pump_station)
      cp  = create(:contact_point, organization: create(:organization, :unit))
      asg = build(:pump_station_assignment, pump_station: ps, assignable: cp)
      expect(asg).to be_valid
    end

    it "accepts WorkGroup as assignable" do
      ps = create(:pump_station)
      wg = create(:work_group)
      asg = build(:pump_station_assignment, pump_station: ps, assignable: wg)
      expect(asg).to be_valid
    end

    it "accepts ContactPointGroup as assignable" do
      ps  = create(:pump_station)
      cpg = create(:contact_point_group)
      asg = build(:pump_station_assignment, pump_station: ps, assignable: cpg)
      expect(asg).to be_valid
    end
  end

  describe "zone-level fixed_pump_percentage validation" do
    let(:zone) { create(:zone) }
    let(:ps1)  { create(:pump_station, zone: zone) }
    let(:ps2)  { create(:pump_station, zone: zone) }
    let(:unit) { create(:organization, :unit) }

    it "rejects when adding percentage causes zone total to exceed 100%" do
      create(:pump_station_assignment, pump_station: ps1, assignable: unit,
             fixed_pump_percentage: 60)
      unit2 = create(:organization, :unit)
      asg = build(:pump_station_assignment, pump_station: ps2, assignable: unit2,
                  fixed_pump_percentage: 50)
      expect(asg).not_to be_valid
      expect(asg.errors[:fixed_pump_percentage]).to be_present
    end

    it "accepts when zone total is exactly 100%" do
      create(:pump_station_assignment, pump_station: ps1, assignable: unit,
             fixed_pump_percentage: 60)
      unit2 = create(:organization, :unit)
      asg = build(:pump_station_assignment, pump_station: ps2, assignable: unit2,
                  fixed_pump_percentage: 40)
      expect(asg).to be_valid
    end

    it "counts assignments across different pump_stations in the same zone" do
      unit2 = create(:organization, :unit)
      create(:pump_station_assignment, pump_station: ps1, assignable: unit,
             fixed_pump_percentage: 70)
      create(:pump_station_assignment, pump_station: ps2, assignable: unit2,
             fixed_pump_percentage: 20)
      unit3 = create(:organization, :unit)
      ps3 = create(:pump_station, zone: zone)
      asg = build(:pump_station_assignment, pump_station: ps3, assignable: unit3,
                  fixed_pump_percentage: 20)
      expect(asg).not_to be_valid
    end

    it "does not count assignments in a different zone" do
      other_zone = create(:zone)
      ps_other = create(:pump_station, zone: other_zone)
      unit2 = create(:organization, :unit)
      create(:pump_station_assignment, pump_station: ps_other, assignable: unit2,
             fixed_pump_percentage: 80)
      asg = build(:pump_station_assignment, pump_station: ps1, assignable: unit,
                  fixed_pump_percentage: 80)
      expect(asg).to be_valid
    end

    it "skips validation when fixed_pump_percentage is nil" do
      create(:pump_station_assignment, pump_station: ps1, assignable: unit,
             fixed_pump_percentage: 90)
      unit2 = create(:organization, :unit)
      asg = build(:pump_station_assignment, pump_station: ps2, assignable: unit2,
                  fixed_pump_percentage: nil)
      expect(asg).to be_valid
    end

    it "skips validation when fixed_pump_percentage is 0" do
      create(:pump_station_assignment, pump_station: ps1, assignable: unit,
             fixed_pump_percentage: 90)
      unit2 = create(:organization, :unit)
      asg = build(:pump_station_assignment, pump_station: ps2, assignable: unit2,
                  fixed_pump_percentage: 0)
      expect(asg).to be_valid
    end

    it "excludes self when updating an existing assignment" do
      asg = create(:pump_station_assignment, pump_station: ps1, assignable: unit,
                   fixed_pump_percentage: 60)
      unit2 = create(:organization, :unit)
      create(:pump_station_assignment, pump_station: ps2, assignable: unit2,
             fixed_pump_percentage: 40)
      # Updating the first assignment from 60 to 70 should fail (70 + 40 = 110)
      asg.fixed_pump_percentage = 70
      expect(asg).not_to be_valid
      expect(asg.errors[:fixed_pump_percentage]).to be_present
    end
  end

  describe "#fixed?" do
    it "is false when fixed_pump_percentage is nil" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: nil).fixed?).to be false
    end

    it "is true when fixed_pump_percentage is 0 (explicit fixed share of 0 kW)" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: 0).fixed?).to be true
    end

    it "is true when fixed_pump_percentage is positive" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: 30).fixed?).to be true
    end
  end

  describe "scopes" do
    let(:ps)   { create(:pump_station) }
    let(:unit) { create(:organization, :unit) }
    let(:cp)   { create(:contact_point, organization: unit) }
    let(:wg)   { create(:work_group) }

    before do
      create(:pump_station_assignment, pump_station: ps, assignable: unit)
      create(:pump_station_assignment, pump_station: ps, assignable: cp)
      create(:pump_station_assignment, pump_station: ps, assignable: wg)
    end

    it "for_organizations returns only Organization assignments" do
      result = PumpStationAssignment.for_organizations([ unit.id ])
      expect(result.pluck(:assignable_type).uniq).to eq([ "Organization" ])
      expect(result.pluck(:assignable_id)).to eq([ unit.id ])
    end

    it "for_assignable returns matching type and id" do
      result = PumpStationAssignment.for_assignable("WorkGroup", wg.id)
      expect(result.count).to eq(1)
      expect(result.first.assignable).to eq(wg)
    end
  end
end
