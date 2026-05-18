require "rails_helper"

RSpec.describe Group do
  describe "associations" do
    it { is_expected.to belong_to(:unit) }
    it { is_expected.to belong_to(:block).optional }
    it { is_expected.to have_many(:contact_points).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:group) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:unit_id) }
  end

  describe "discard" do
    it "có scope kept" do
      expect(Group).to respond_to(:kept)
    end
  end
end
