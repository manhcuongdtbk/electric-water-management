require "rails_helper"

RSpec.describe MainMeterReading do
  describe "associations" do
    it { is_expected.to belong_to(:main_meter) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:main_meter_reading) }
    it { is_expected.to validate_presence_of(:usage) }
    it { is_expected.to validate_numericality_of(:usage).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_uniqueness_of(:main_meter_id).scoped_to(:period_id) }
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(MainMeterReading.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      reading = create(:main_meter_reading)
      copy = MainMeterReading.find(reading.id)
      reading.update!(usage: 999)
      expect { copy.update!(usage: 888) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
