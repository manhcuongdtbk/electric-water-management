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

    context "pair validation" do
      it "rejects reading_start=nil when reading_end is present" do
        reading = build(:meter_reading, reading_start: nil, reading_end: 100, consumption: nil)
        expect(reading).not_to be_valid
        expect(reading.errors[:reading_start]).to include("phải được nhập khi có chỉ số cuối kỳ")
      end

      it "rejects reading_end=nil when reading_start is present" do
        reading = build(:meter_reading, reading_start: 50, reading_end: nil, consumption: nil)
        expect(reading).not_to be_valid
        expect(reading.errors[:reading_end]).to include("phải được nhập khi có chỉ số đầu kỳ")
      end

      it "allows both readings nil (no pair to validate)" do
        expect(build(:meter_reading, reading_start: nil, reading_end: nil, consumption: nil)).to be_valid
      end

      it "allows both readings present (full pair)" do
        expect(build(:meter_reading, reading_start: 50, reading_end: 100, consumption: 50)).to be_valid
      end
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
