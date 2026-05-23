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

  describe "after_create :create_current_period_unit_config" do
    let(:zone) { create(:zone) }
    let!(:period) { create(:period, closed: false) }

    it "tạo UnitConfig cho kỳ đang mở khi tạo đơn vị mới" do
      unit = create(:unit, zone: zone)
      config = UnitConfig.find_by(unit: unit, period: period)
      expect(config).to be_present
      expect(config.unit_public_rate).to eq(0)
    end

    it "không tạo UnitConfig khi không có kỳ đang mở" do
      period.update!(closed: true)
      unit = create(:unit, zone: zone)
      expect(UnitConfig.where(unit: unit)).to be_empty
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

  describe "before_discard :cleanup_current_period_data (C1)" do
    let!(:period) { create(:period, closed: false) }
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }

    it "hard delete unit_configs kỳ đang mở, giữ kỳ cũ" do
      old_period = create(:period, year: 2025, month: 1, closed: true)
      UnitConfig.create!(unit: unit, period: old_period, unit_public_rate: 5)
      config_current = UnitConfig.find_by(unit: unit, period: period)
      config_old = UnitConfig.find_by(unit: unit, period: old_period)

      unit.discard
      expect(UnitConfig.find_by(id: config_current.id)).to be_nil
      expect(UnitConfig.find_by(id: config_old.id)).to be_present
    end

    it "hard delete pump_allocations kỳ đang mở, giữ kỳ cũ" do
      alloc_current = PumpAllocation.create!(zone: zone, period: period, unit: unit, coefficient: 1)
      old_period = create(:period, year: 2025, month: 1, closed: true)
      alloc_old = PumpAllocation.create!(zone: zone, period: old_period, unit: unit, coefficient: 1)

      unit.discard
      expect(PumpAllocation.find_by(id: alloc_current.id)).to be_nil
      expect(PumpAllocation.find_by(id: alloc_old.id)).to be_present
    end
  end

  describe "after_discard :discard_blocks_and_groups (I6)" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let!(:period) { create(:period, closed: false) }

    it "cascade discard blocks và groups" do
      block = create(:block, unit: unit)
      group = create(:group, unit: unit)
      unit.discard
      expect(block.reload).to be_discarded
      expect(group.reload).to be_discarded
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
