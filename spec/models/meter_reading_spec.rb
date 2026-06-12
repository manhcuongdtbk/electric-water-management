require "rails_helper"

RSpec.describe MeterReading do
  describe "associations" do
    it { is_expected.to belong_to(:meter) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:meter_reading) }
    it { is_expected.to validate_presence_of(:reading_start) }
    it { is_expected.to validate_numericality_of(:reading_start).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:reading_end).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:manual_usage).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_uniqueness_of(:meter_id).scoped_to(:period_id) }
  end

  describe "#usage" do
    it "trả về manual_usage khi có" do
      reading = build(:meter_reading, reading_start: 100, reading_end: 200, manual_usage: 50)
      expect(reading.usage).to eq(50)
    end

    it "trả về reading_end - reading_start khi không có manual_usage" do
      reading = build(:meter_reading, reading_start: 100, reading_end: 250, manual_usage: nil)
      expect(reading.usage).to eq(150)
    end

    it "trả về nil khi reading_end nil và không có manual_usage" do
      reading = build(:meter_reading, reading_start: 100, reading_end: nil, manual_usage: nil)
      expect(reading.usage).to be_nil
    end
  end

  describe "#actual_usage" do
    it "trả nil khi chưa có loss (chưa tính)" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: nil)
      expect(mr.actual_usage).to be_nil
    end

    it "= usage + loss khi đã có loss" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: BigDecimal("7.5"))
      expect(mr.actual_usage).to eq(BigDecimal("57.5"))
    end

    it "trả nil khi loss có nhưng usage nil (reading_end trống)" do
      mr = MeterReading.new(reading_start: 100, reading_end: nil, loss: BigDecimal("7.5"))
      expect(mr.actual_usage).to be_nil
    end

    it "loss = 0 → actual_usage = usage (công tơ no_loss)" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: BigDecimal("0"))
      expect(mr.actual_usage).to eq(BigDecimal("50"))
    end
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(MeterReading.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      reading = create(:meter_reading)
      copy = MeterReading.find(reading.id)
      reading.update!(reading_end: 999)
      expect { copy.update!(reading_end: 888) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
