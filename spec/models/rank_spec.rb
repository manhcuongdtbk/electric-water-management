require "rails_helper"

RSpec.describe Rank do
  describe "associations" do
    it { is_expected.to belong_to(:period) }
    it { is_expected.to have_many(:personnel_entries).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:rank) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:quota).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer }
  end
end
