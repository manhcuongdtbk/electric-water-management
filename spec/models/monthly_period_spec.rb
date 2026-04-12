require "rails_helper"

RSpec.describe MonthlyPeriod, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:locked_by).class_name("User").optional }
    it { is_expected.to have_many(:meter_readings) }
    it { is_expected.to have_many(:personnel_records).class_name("Personnel") }
    it "personnel_records uses monthly_period_id FK" do
      assoc = MonthlyPeriod.reflect_on_association(:personnel_records)
      expect(assoc.foreign_key.to_sym).to eq(:monthly_period_id)
    end
    it { is_expected.to have_many(:unit_configs) }
    it { is_expected.to have_many(:monthly_calculations) }
  end

  describe "validations" do
    subject { build(:monthly_period, month: 3) }

    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_uniqueness_of(:month).scoped_to(:year) }

    it "rejects year below 2020" do
      expect(build(:monthly_period, year: 2019, month: 1)).not_to be_valid
    end

    it "rejects year above 2100" do
      expect(build(:monthly_period, year: 2101, month: 1)).not_to be_valid
    end

    it "rejects month 0" do
      expect(build(:monthly_period, month: 0)).not_to be_valid
    end

    it "rejects month 13" do
      expect(build(:monthly_period, month: 13)).not_to be_valid
    end

    it "rejects negative unit_price" do
      expect(build(:monthly_period, month: 4, unit_price: -100)).not_to be_valid
    end

    it "allows nil unit_price" do
      expect(build(:monthly_period, month: 5, unit_price: nil)).to be_valid
    end

    it "is invalid when locked but no locked_by" do
      period = build(:monthly_period, month: 6, locked: true, locked_by: nil)
      expect(period).not_to be_valid
      expect(period.errors[:locked_by]).to be_present
    end

    it "is valid when locked with locked_by" do
      user = create(:user)
      period = build(:monthly_period, :locked, month: 7, locked_by: user)
      expect(period).to be_valid
    end
  end

  describe "#label" do
    it "formats year/month as YYYY/MM" do
      period = build(:monthly_period, year: 2026, month: 2)
      expect(period.label).to eq("2026/02")
    end
  end

  describe "#lock! and #unlock!" do
    let!(:user)   { create(:user) }
    let!(:period) { create(:monthly_period, month: 8) }

    it "locks the period" do
      period.lock!(user)
      expect(period.reload).to be_locked
      expect(period.locked_by).to eq(user)
    end

    it "unlocks the period" do
      period.lock!(user)
      period.unlock!
      expect(period.reload).not_to be_locked
      expect(period.locked_by).to be_nil
    end
  end
end
