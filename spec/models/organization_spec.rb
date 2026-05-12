require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "associations" do
    # Use a division subject so the conditional `validates :zone, presence:
    # true, if: unit?` doesn't fight the shoulda `belong_to(:zone).optional`
    # matcher (the matcher unsets zone and expects validity).
    subject { build(:organization, :division) }

    it { is_expected.to belong_to(:parent).class_name("Organization").optional }
    it { is_expected.to belong_to(:main_meter).optional }
    it { is_expected.to belong_to(:zone).optional }
    it { is_expected.to have_many(:children).class_name("Organization").with_foreign_key(:parent_id) }
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:contact_points) }
    it { is_expected.to have_many(:meters) }
    it { is_expected.to have_many(:unit_configs) }
    it { is_expected.to have_many(:pump_stations) }
    it { is_expected.to have_many(:pump_station_assignments) }
  end

  describe "validations" do
    subject { build(:organization, :division) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:level) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:level) }

    it "is valid with level division and no parent" do
      org = build(:organization, :division)
      expect(org).to be_valid
    end

    it "is invalid for division with a parent" do
      parent = create(:organization, :division)
      org = build(:organization, :division, parent: parent)
      expect(org).not_to be_valid
      expect(org.errors[:parent_id]).to be_present
    end

    it "is valid for unit with a division parent" do
      parent = create(:organization, :division)
      org = build(:organization, :unit, parent: parent)
      expect(org).to be_valid
    end

    it "is invalid for unit with a unit parent" do
      parent = create(:organization, :division)
      unit_parent = create(:organization, :unit, parent: parent)
      org = build(:organization, :unit, parent: unit_parent)
      expect(org).not_to be_valid
      expect(org.errors[:parent_id]).to be_present
    end

    it "allows zone to be blank for any level (form-flow does not yet enforce it)" do
      div = create(:organization, :division)
      unit = build(:organization, :unit, parent: div, zone: nil)
      expect(unit).to be_valid
      expect(build(:organization, :division, zone: nil)).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:level).with_values(division: 1, unit: 2) }
  end

  describe "scopes" do
    let!(:division) { create(:organization, :division) }
    let!(:unit1)    { create(:organization, :unit, parent: division, position: 2) }
    let!(:unit2)    { create(:organization, :unit, parent: division, position: 1) }

    it ".divisions returns only divisions" do
      expect(Organization.divisions).to include(division)
      expect(Organization.divisions).not_to include(unit1, unit2)
    end

    it ".units returns only units" do
      expect(Organization.units).to include(unit1, unit2)
      expect(Organization.units).not_to include(division)
    end

    it ".ordered sorts by position then name" do
      ordered = Organization.units.ordered.to_a
      expect(ordered.first).to eq(unit2)
    end

    it ".by_parent filters by parent_id" do
      expect(Organization.by_parent(division.id)).to include(unit1, unit2)
    end
  end

  describe "before_destroy :prevent_destroy_division" do
    it "blocks destroying a division" do
      division = create(:organization, :division)
      expect(division.destroy).to be false
      expect(Organization.exists?(division.id)).to be true
      expect(division.errors[:base]).to be_present
    end

    it "allows destroying a unit with no related data" do
      division = create(:organization, :division)
      unit = create(:organization, :unit, parent: division)
      expect { unit.destroy }.to change(Organization.units, :count).by(-1)
    end
  end
end
