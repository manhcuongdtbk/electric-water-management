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

  describe "after_discard cascade nullify (T43)" do
    let(:unit) { create(:unit) }
    let(:group) { create(:group, unit: unit, name: "Ban Tác huấn") }

    it "nullify group_id trên contact_points kept" do
      cp = create(:contact_point, :residential, unit: unit, group: group)
      group.discard
      expect(cp.reload.group_id).to be_nil
    end

    it "validate_block_unit_match: block phải cùng unit (I3)" do
      other_unit = create(:unit, zone: unit.zone)
      other_block = create(:block, unit: other_unit)
      group = build(:group, unit: unit, block: other_block, name: "Nhóm sai block")
      expect(group).not_to be_valid
      expect(group.errors[:block_id]).to be_present
    end

    it "đầu mối vẫn giữ block_id (chỉ nhóm bị xóa)" do
      block = create(:block, unit: unit)
      group_with_block = create(:group, unit: unit, block: block, name: "Nhóm trong khối")
      cp = create(:contact_point, :residential, unit: unit, block: block, group: group_with_block)
      group_with_block.discard
      cp.reload
      expect(cp.group_id).to be_nil
      expect(cp.block_id).to eq(block.id)
    end
  end
end
