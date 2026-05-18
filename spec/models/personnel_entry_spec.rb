require "rails_helper"

RSpec.describe PersonnelEntry do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:period) }
    it { is_expected.to belong_to(:rank) }
  end

  describe "validations" do
    subject { build(:personnel_entry) }
    it { is_expected.to validate_presence_of(:count) }
    it { is_expected.to validate_numericality_of(:count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:period_id, :rank_id) }
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(PersonnelEntry.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      entry = create(:personnel_entry)
      copy = PersonnelEntry.find(entry.id)
      entry.update!(count: 5)
      expect { copy.update!(count: 7) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
