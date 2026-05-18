require "rails_helper"

RSpec.describe Zone do
  describe "associations" do
    it { is_expected.to have_many(:units).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:contact_points).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:main_meters).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:pump_allocations).dependent(:restrict_with_error) }
    it { is_expected.to belong_to(:manager_unit).class_name("Unit").optional }
  end

  describe "validations" do
    subject { build(:zone) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end
end
