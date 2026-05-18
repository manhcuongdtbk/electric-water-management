require "rails_helper"

RSpec.describe Period do
  describe "associations" do
    it { is_expected.to have_many(:ranks).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:meter_readings).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:main_meter_readings).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:personnel_entries).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:non_establishment_snapshots).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:unit_configs).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:other_deductions).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:calculations).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:pump_allocations).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:period) }

    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_uniqueness_of(:month).scoped_to(:year) }
    it { is_expected.to validate_numericality_of(:unit_price).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:savings_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_numericality_of(:division_public_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_numericality_of(:water_pump_standard).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:month).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }
  end

  describe ".current" do
    it "trả về kỳ đang mở" do
      closed_period = create(:period, year: 2025, month: 1, closed: true)
      open_period = create(:period, year: 2026, month: 1, closed: false)
      expect(Period.current).to eq(open_period)
    end

    it "trả về nil khi không có kỳ mở" do
      create(:period, closed: true)
      expect(Period.current).to be_nil
    end
  end

  describe "#open?" do
    it "true khi closed = false" do
      expect(build(:period, closed: false).open?).to be true
    end

    it "false khi closed = true" do
      expect(build(:period, closed: true).open?).to be false
    end
  end

  describe "partial unique index" do
    it "chặn tạo 2 kỳ cùng mở" do
      create(:period, year: 2025, month: 1, closed: false)
      expect {
        create(:period, year: 2025, month: 2, closed: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "cho phép nhiều kỳ closed = true" do
      create(:period, year: 2025, month: 1, closed: true)
      expect {
        create(:period, year: 2025, month: 2, closed: true)
      }.not_to raise_error
    end
  end
end
