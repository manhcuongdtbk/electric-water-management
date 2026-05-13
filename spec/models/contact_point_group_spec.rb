require "rails_helper"

RSpec.describe ContactPointGroup, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:contact_point_group_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:contact_points).through(:contact_point_group_memberships) }
    it { is_expected.to have_many(:pump_station_assignments).dependent(:restrict_with_error) }
  end

  it "has paper_trail enabled" do
    expect(ContactPointGroup).to respond_to(:paper_trail)
  end

  describe "validations" do
    subject { build(:contact_point_group) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id) }
  end

  describe "scopes" do
    it ".ordered sorts by name" do
      org = create(:organization)
      b = create(:contact_point_group, organization: org, name: "Beta")
      a = create(:contact_point_group, organization: org, name: "Alpha")
      c = create(:contact_point_group, organization: org, name: "Gamma")

      expect(ContactPointGroup.ordered.to_a).to eq([ a, b, c ])
    end
  end

  describe "#total_personnel" do
    it "sums rank counts across joined personnel_records" do
      org = create(:organization)
      group = create(:contact_point_group, organization: org)
      cp = create(:contact_point, organization: org)
      create(:contact_point_group_membership, contact_point_group: group, contact_point: cp)
      period = create(:monthly_period)
      create(:personnel, contact_point: cp, monthly_period: period,
             rank1_count: 5, rank2_count: 3, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      expect(group.total_personnel).to eq(8)
    end

    it "returns 0 when no contact_points" do
      group = create(:contact_point_group)
      expect(group.total_personnel).to eq(0)
    end
  end

  describe "#destroy" do
    it "is blocked when pump_station_assignments exist" do
      group = create(:contact_point_group)
      # ContactPointGroup will be added to ALLOWED_ASSIGNABLE_TYPES in next PR;
      # bypass model validation here to test the restrict_with_error dependency.
      ps = create(:pump_station)
      PumpStationAssignment.new(pump_station: ps, assignable: group).save(validate: false)

      expect { group.destroy }.not_to change(ContactPointGroup, :count)
      expect(group.errors[:base]).to be_present
    end

    it "succeeds when no pump_station_assignments exist" do
      group = create(:contact_point_group)
      expect { group.destroy }.to change(ContactPointGroup, :count).by(-1)
    end
  end
end
