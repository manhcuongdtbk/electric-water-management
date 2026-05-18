require "rails_helper"

RSpec.describe Meter do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to have_many(:meter_readings) }
  end

  describe "validations" do
    subject { build(:meter) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:contact_point_id) }
  end

  describe "#contact_point_type" do
    it "delegate xuống contact_point" do
      cp = create(:contact_point, :water_pump)
      meter = create(:meter, contact_point: cp)
      expect(meter.contact_point_type).to eq("water_pump")
    end
  end

  describe "scope :in_zone" do
    it "trả về meter của contact_points trong zone" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      cp = create(:contact_point, :residential, unit: unit)
      meter = create(:meter, contact_point: cp)
      other_meter = create(:meter)

      expect(Meter.in_zone(zone)).to include(meter)
      expect(Meter.in_zone(zone)).not_to include(other_meter)
    end
  end

  describe "discard" do
    it "có scope kept" do
      expect(Meter).to respond_to(:kept)
    end
  end
end
