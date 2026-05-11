require "rails_helper"

RSpec.describe MainMeterReading, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:main_meter) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "validations" do
    subject { build(:main_meter_reading) }

    it { is_expected.to validate_presence_of(:electricity_supply_kw) }
    it { is_expected.to validate_uniqueness_of(:main_meter_id).scoped_to(:monthly_period_id) }

    it "rejects negative electricity_supply_kw" do
      expect(build(:main_meter_reading, electricity_supply_kw: -1)).not_to be_valid
    end

    it "accepts zero" do
      expect(build(:main_meter_reading, electricity_supply_kw: 0)).to be_valid
    end
  end

  describe "scopes" do
    let(:period)     { create(:monthly_period) }
    let(:other_period) { create(:monthly_period, year: 2030, month: 1) }
    let(:main_meter) { create(:main_meter) }
    let(:other_mm)   { create(:main_meter) }
    let!(:reading_in) { create(:main_meter_reading, main_meter: main_meter, monthly_period: period) }
    let!(:reading_out) { create(:main_meter_reading, main_meter: other_mm, monthly_period: other_period) }

    it ".for_period filters by monthly_period_id" do
      expect(described_class.for_period(period.id)).to contain_exactly(reading_in)
    end

    it ".for_main_meter filters by main_meter_id" do
      expect(described_class.for_main_meter(main_meter.id)).to contain_exactly(reading_in)
    end
  end

  describe "papertrail" do
    it "records versions on update" do
      reading = create(:main_meter_reading)
      expect { reading.update!(electricity_supply_kw: 9999) }
        .to change { PaperTrail::Version.where(item: reading).count }.by(1)
    end
  end
end
