require "rails_helper"

RSpec.describe Unit do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to have_many(:contact_points).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:blocks).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:groups).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:users).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:unit_configs) }
    it { is_expected.to have_many(:pump_allocations) }
    it { is_expected.to have_many(:managed_zones).class_name("Zone").with_foreign_key(:manager_unit_id).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:unit) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe "after_create :assign_as_zone_manager" do
    let(:zone) { create(:zone) }

    it "gán đơn vị làm manager khi là đơn vị đầu tiên trong khu vực" do
      unit = create(:unit, zone: zone)
      expect(zone.reload.manager_unit_id).to eq(unit.id)
    end

    it "không gán khi khu vực đã có manager" do
      first_unit = create(:unit, zone: zone)
      second_unit = create(:unit, zone: zone)
      expect(zone.reload.manager_unit_id).to eq(first_unit.id)
      expect(zone.manager_unit_id).not_to eq(second_unit.id)
    end
  end

  describe "discard" do
    it "có scope kept" do
      kept = create(:unit)
      discarded = create(:unit)
      discarded.discard
      expect(Unit.kept).to include(kept)
      expect(Unit.kept).not_to include(discarded)
    end
  end
end
