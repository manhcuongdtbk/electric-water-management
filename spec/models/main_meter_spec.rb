require "rails_helper"

RSpec.describe MainMeter do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to have_many(:main_meter_readings) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "discard" do
    it "có scope kept" do
      expect(MainMeter).to respond_to(:kept)
    end
  end
end
