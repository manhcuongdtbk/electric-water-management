require "rails_helper"

RSpec.describe ContactPoint, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:meters) }
    it { is_expected.to have_many(:personnel_records).class_name("Personnel") }
    it "personnel_records uses contact_point_id FK" do
      assoc = ContactPoint.reflect_on_association(:personnel_records)
      expect(assoc.foreign_key.to_sym).to eq(:contact_point_id)
    end
    it { is_expected.to have_many(:monthly_calculations) }
  end

  describe "validations" do
    subject { build(:contact_point) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id) }
    it { is_expected.to validate_length_of(:group_name).is_at_most(100) }

    it "allows blank group_name" do
      cp = build(:contact_point, group_name: nil)
      expect(cp).to be_valid
    end

    it "prevents duplicate name within same organization" do
      org = create(:organization)
      create(:contact_point, name: "Ban chi huy", organization: org)
      dup = build(:contact_point, name: "Ban chi huy", organization: org)
      expect(dup).not_to be_valid
    end

    it "allows same name in different organizations" do
      org1 = create(:organization, :division)
      org2 = create(:organization, :division)
      create(:contact_point, name: "Ban chi huy", organization: org1)
      cp = build(:contact_point, name: "Ban chi huy", organization: org2)
      expect(cp).to be_valid
    end
  end

  describe "scopes" do
    let!(:org) { create(:organization) }
    let!(:cp1) { create(:contact_point, organization: org, group_name: "A", position: 2) }
    let!(:cp2) { create(:contact_point, organization: org, group_name: "B", position: 1) }
    let!(:cp3) { create(:contact_point) }

    it ".by_organization filters correctly" do
      expect(ContactPoint.by_organization(org.id)).to include(cp1, cp2)
      expect(ContactPoint.by_organization(org.id)).not_to include(cp3)
    end

    it ".ordered sorts by position" do
      expect(ContactPoint.by_organization(org.id).ordered.first).to eq(cp2)
    end

    it ".by_group filters by group_name" do
      expect(ContactPoint.by_group("A")).to include(cp1)
      expect(ContactPoint.by_group("A")).not_to include(cp2)
    end
  end
end
