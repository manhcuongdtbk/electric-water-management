require "rails_helper"

RSpec.describe Calculation do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:calculation) }
    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:period_id) }
  end
end
