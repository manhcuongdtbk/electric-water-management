require "rails_helper"

RSpec.describe Zone, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:manager_organization).class_name("Organization").optional }
    it { is_expected.to have_many(:main_meters).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:organizations).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:pump_stations).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:zone) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "scopes" do
    it ".ordered sorts by name" do
      z2 = create(:zone, name: "B zone")
      z1 = create(:zone, name: "A zone")
      expect(Zone.ordered).to eq([ z1, z2 ])
    end
  end

  describe "dependent: :restrict_with_error" do
    it "blocks destroy when a main_meter still references it" do
      zone = create(:zone)
      create(:main_meter, zone: zone)
      expect(zone.destroy).to be false
      expect(zone.errors[:base]).to be_present
    end

    it "blocks destroy when an organization still references it" do
      zone = create(:zone)
      div  = create(:organization, :division)
      create(:organization, :unit, parent: div, zone: zone)
      expect(zone.destroy).to be false
      expect(zone.errors[:base]).to be_present
    end

    it "blocks destroy when a pump_station still references it" do
      zone = create(:zone)
      create(:pump_station, zone: zone)
      expect(zone.destroy).to be false
      expect(zone.errors[:base]).to be_present
    end

    it "allows destroy when no child records exist" do
      zone = create(:zone)
      expect { zone.destroy! }.to change(Zone, :count).by(-1)
    end
  end

  describe "papertrail" do
    it "records versions on update" do
      zone = create(:zone)
      expect { zone.update!(name: "Renamed zone") }
        .to change { PaperTrail::Version.where(item: zone).count }.by(1)
    end
  end
end
