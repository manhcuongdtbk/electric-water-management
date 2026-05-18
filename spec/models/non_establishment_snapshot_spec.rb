require "rails_helper"

RSpec.describe NonEstablishmentSnapshot do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:non_establishment_snapshot) }
    it { is_expected.to validate_presence_of(:personnel_count) }
    it { is_expected.to validate_numericality_of(:personnel_count).only_integer.is_greater_than_or_equal_to(1) }
    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:period_id) }
  end
end
