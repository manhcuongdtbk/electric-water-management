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

  describe "#calculation_state_targets" do
    it "returns nil zone_id when main_meter is nil" do
      reading = MainMeterReading.new(period_id: 1)
      targets = reading.send(:calculation_state_targets)
      expect(targets).to eq([[nil, 1]])
    end
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
