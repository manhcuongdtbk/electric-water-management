require "rails_helper"

RSpec.describe ContactPointGroupMembership, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point_group) }
    it { is_expected.to belong_to(:contact_point) }
  end

  it "has paper_trail enabled" do
    expect(ContactPointGroupMembership).to respond_to(:paper_trail)
  end

  describe "same_organization validation" do
    let(:division) { create(:organization, :division) }
    let(:org_a) { create(:organization, :unit, parent: division) }
    let(:org_b) { create(:organization, :unit, parent: division) }

    it "is valid when group and contact_point belong to the same org" do
      group = create(:contact_point_group, organization: org_a)
      cp = create(:contact_point, organization: org_a)
      membership = build(:contact_point_group_membership, contact_point_group: group, contact_point: cp)
      expect(membership).to be_valid
    end

    it "is invalid when group and contact_point belong to different orgs" do
      group = create(:contact_point_group, organization: org_a)
      cp = create(:contact_point, organization: org_b)
      membership = build(:contact_point_group_membership, contact_point_group: group, contact_point: cp)
      expect(membership).not_to be_valid
      expect(membership.errors[:contact_point]).to be_present
    end
  end
end
