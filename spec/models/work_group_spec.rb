require "rails_helper"

RSpec.describe WorkGroup, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:owner_organization).class_name("Organization") }
    it { is_expected.to have_many(:pump_station_assignments).dependent(:restrict_with_error) }
  end

  it "has paper_trail enabled" do
    expect(WorkGroup).to respond_to(:paper_trail)
  end

  describe "validations" do
    subject { build(:work_group) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:owner_organization_id) }
    it { is_expected.to validate_numericality_of(:personnel_count)
                          .only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:position)
                          .only_integer.is_greater_than_or_equal_to(0) }

    it "rejects unit-level Organization as owner" do
      unit = create(:organization, :unit)
      wg = build(:work_group, owner_organization: unit)
      expect(wg).not_to be_valid
      expect(wg.errors[:owner_organization]).to be_present
    end

    it "accepts division-level Organization as owner" do
      div = create(:organization, :division)
      wg = build(:work_group, owner_organization: div)
      expect(wg).to be_valid
    end
  end

  describe "scopes" do
    it ".ordered sorts by position then name" do
      div = create(:organization, :division)
      b = create(:work_group, owner_organization: div, name: "Beta", position: 1)
      a = create(:work_group, owner_organization: div, name: "Alpha", position: 2)
      c = create(:work_group, owner_organization: div, name: "Gamma", position: 0)

      expect(WorkGroup.ordered.to_a).to eq([ c, b, a ])
    end
  end

  describe "#destroy" do
    it "is blocked when assignments exist" do
      wg = create(:work_group)
      create(:pump_station_assignment, assignable: wg)

      expect { wg.destroy }.not_to change(WorkGroup, :count)
      expect(wg.errors[:base]).to be_present
    end

    it "succeeds when no assignments exist" do
      wg = create(:work_group)
      expect { wg.destroy }.to change(WorkGroup, :count).by(-1)
    end
  end
end
