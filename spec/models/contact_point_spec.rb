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

  describe "enums" do
    it {
      is_expected.to define_enum_for(:contact_point_type)
        .with_values(residential: 0, communal: 1)
    }

    it "defaults to residential" do
      expect(build(:contact_point).contact_point_type).to eq("residential")
    end
  end

  describe "ransackable_attributes" do
    it "exposes contact_point_type for filtering" do
      expect(ContactPoint.ransackable_attributes).to include("contact_point_type")
    end
  end

  describe "scopes" do
    let!(:org) { create(:organization) }
    let!(:cp1) { create(:contact_point, organization: org, group_name: "A", position: 2) }
    let!(:cp2) { create(:contact_point, organization: org, group_name: "B", position: 1) }
    let!(:cp3) { create(:contact_point) }
    let!(:cp_communal) { create(:contact_point, :communal, organization: org, position: 9) }

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

    it ".residential returns only residential CPs" do
      expect(ContactPoint.residential).to include(cp1, cp2, cp3)
      expect(ContactPoint.residential).not_to include(cp_communal)
    end

    it ".communal returns only communal CPs" do
      expect(ContactPoint.communal).to include(cp_communal)
      expect(ContactPoint.communal).not_to include(cp1, cp2, cp3)
    end
  end
end
