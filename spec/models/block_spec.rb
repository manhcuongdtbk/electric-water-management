require "rails_helper"

RSpec.describe Block do
  describe "associations" do
    it { is_expected.to belong_to(:unit) }
    it { is_expected.to have_many(:groups).dependent(:nullify) }
    it { is_expected.to have_many(:contact_points).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:block) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:unit_id) }
  end

  describe "discard" do
    it "có scope kept" do
      expect(Block).to respond_to(:kept)
    end
  end
end
