require "rails_helper"

RSpec.describe MeterReading, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:meter) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "validations" do
    subject { build(:meter_reading) }

    it { is_expected.to validate_uniqueness_of(:meter_id).scoped_to(:monthly_period_id) }

    it "rejects negative reading_start" do
      expect(build(:meter_reading, reading_start: -1)).not_to be_valid
    end

    it "rejects reading_end less than reading_start" do
      reading = build(:meter_reading, reading_start: 500, reading_end: 400)
      expect(reading).not_to be_valid
      expect(reading.errors[:reading_end]).to be_present
    end

    it "allows nil readings" do
      expect(build(:meter_reading, reading_start: nil, reading_end: nil, consumption: nil)).to be_valid
    end
  end

  describe "scopes" do
    it ".by_organization filters by meter's organization" do
      org = create(:organization)
      meter = create(:meter, organization: org)
      reading = create(:meter_reading, meter: meter)
      other = create(:meter_reading)
      expect(MeterReading.by_organization(org.id)).to include(reading)
      expect(MeterReading.by_organization(org.id)).not_to include(other)
    end
  end

  describe "before_save" do
    it "calculates consumption from readings" do
      reading = create(:meter_reading, reading_start: 1000, reading_end: 1300, consumption: nil)
      expect(reading.consumption).to eq(300)
    end

    it "does not calculate if readings are nil" do
      reading = create(:meter_reading, reading_start: nil, reading_end: nil, consumption: nil)
      expect(reading.consumption).to be_nil
    end
  end
end
