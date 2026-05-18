require "rails_helper"

RSpec.describe Block do
  describe "associations" do
    it { is_expected.to belong_to(:unit) }
    it { is_expected.to have_many(:groups).dependent(:nullify) }
    it { is_expected.to have_many(:contact_points).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:block) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:unit_id) }
  end

  describe "discard" do
    it "có scope kept" do
      expect(Block).to respond_to(:kept)
    end
  end

  describe "after_discard cascade nullify (T42)" do
    let(:unit) { create(:unit) }
    let(:block) { create(:block, unit: unit, name: "Phòng Tham mưu") }

    it "nullify block_id trên groups kept" do
      group = create(:group, unit: unit, block: block, name: "Nhóm A")
      block.discard
      expect(group.reload.block_id).to be_nil
    end

    it "nullify block_id trên contact_points kept" do
      cp = create(:contact_point, :residential, unit: unit, block: block)
      block.discard
      expect(cp.reload.block_id).to be_nil
    end

    it "không nullify discarded groups" do
      group = create(:group, unit: unit, block: block, name: "Nhóm B")
      group.discard
      block.discard
      # discarded group giữ nguyên block_id (chỉ kept mới bị nullify)
      expect(group.reload.block_id).to eq(block.id)
    end
  end
end
