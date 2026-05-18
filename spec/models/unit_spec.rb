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

  describe "validate :immutable_zone_id (T30)" do
    it "không cho đổi zone_id sau khi tạo" do
      zone_a = create(:zone)
      zone_b = create(:zone)
      unit = create(:unit, zone: zone_a)
      unit.zone_id = zone_b.id
      expect(unit).not_to be_valid
      expect(unit.errors[:zone_id]).to include(
        I18n.t("activerecord.errors.models.unit.attributes.zone_id.immutable")
      )
    end
  end

  describe "before_discard :ensure_no_kept_dependents (T39)" do
    let(:unit) { create(:unit) }

    it "chặn discard nếu còn contact_point kept" do
      create(:contact_point, :residential, unit: unit)
      expect(unit.discard).to be false
      expect(unit.errors[:base]).to include(
        I18n.t("activerecord.errors.models.unit.attributes.base.has_kept_contact_points")
      )
    end

    it "chặn discard nếu còn user" do
      create(:user, :unit_admin, unit: unit)
      expect(unit.discard).to be false
      expect(unit.errors[:base]).to include(
        I18n.t("activerecord.errors.models.unit.attributes.base.has_users")
      )
    end

    it "cho discard khi đã xóa hết dependents" do
      expect(unit.discard).to be true
      expect(unit.reload).to be_discarded
    end
  end

  describe "before_discard :clear_zone_manager_if_self (T41)" do
    it "set zones.manager_unit_id = nil khi discard unit là manager" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      expect(zone.reload.manager_unit_id).to eq(unit.id)
      unit.discard
      expect(zone.reload.manager_unit_id).to be_nil
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
