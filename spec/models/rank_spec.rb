require "rails_helper"

RSpec.describe Rank do
  describe "associations" do
    it { is_expected.to belong_to(:period) }
    it { is_expected.to have_many(:personnel_entries).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:rank) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:quota).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer }
  end

  describe "before_destroy :ensure_no_entries_with_personnel (T44)" do
    let(:period) { create(:period, closed: false) }
    # Tạo trước rank khác (active) để CP có ít nhất 1 quân số > 0
    let!(:rank_main) { create(:rank, period: period, position: 1, name: "Rank chính") }
    let(:rank_under_test) { create(:rank, period: period, position: 99, name: "Test rank") }

    it "cho xóa nếu mọi personnel_entries của rank có count = 0" do
      unit = create(:unit)
      create(:contact_point, :residential, unit: unit,
             initial_personnel_counts: { rank_main.id => 5 })
      # rank_under_test tạo sau CP → seed_personnel_entries cho CP active với count = 0
      rank_under_test
      expect(rank_under_test.destroy).to be_truthy
    end

    it "chặn xóa nếu có personnel_entries.count > 0" do
      unit = create(:unit)
      create(:contact_point, :residential, unit: unit,
             initial_personnel_counts: { rank_main.id => 5, rank_under_test.id => 3 })
      expect(rank_under_test.destroy).to be false
      expect(rank_under_test.errors[:base]).to include(
        I18n.t("activerecord.errors.models.rank.attributes.base.has_personnel_entries_in_use")
      )
    end
  end

  describe "validates position uniqueness scoped to period (N2)" do
    let(:period) { create(:period, closed: false) }
    let!(:rank1) { create(:rank, period: period, position: 1, name: "Rank 1", quota: 100) }

    it "chặn trùng position trong cùng period" do
      rank2 = build(:rank, period: period, position: 1, name: "Rank 2", quota: 200)
      expect(rank2).not_to be_valid
      expect(rank2.errors[:position]).to be_present
    end

    it "cho phép cùng position ở period khác" do
      other_period = create(:period, year: 2025, month: 1, closed: true)
      rank2 = build(:rank, period: other_period, position: 1, name: "Rank 2", quota: 200)
      expect(rank2).to be_valid
    end
  end

  describe "after_create :seed_personnel_entries_for_residentials" do
    let(:period) { create(:period, closed: false) }

    it "không tạo entries nếu chưa có residential nào active trong period" do
      rank = create(:rank, period: period, position: 99, name: "Mới")
      expect(rank.personnel_entries.count).to eq(0)
    end

    it "tạo entries(count=0) cho residential đã active trong period" do
      first_rank = period.ranks.create!(name: "Rank đầu", quota: 100, position: 1)
      unit = create(:unit)
      cp = create(:contact_point, :residential, unit: unit,
                  initial_personnel_counts: { first_rank.id => 5 })
      new_rank = create(:rank, period: period, position: 98, name: "Mới sau khi có CP")
      pe = new_rank.personnel_entries.find_by(contact_point: cp, period: period)
      expect(pe).to be_present
      expect(pe.count).to eq(0)
    end

    it "không tạo cho residential discarded" do
      first_rank = period.ranks.create!(name: "R1", quota: 100, position: 1)
      unit = create(:unit)
      cp = create(:contact_point, :residential, unit: unit,
                  initial_personnel_counts: { first_rank.id => 1 })
      cp.discard
      new_rank = create(:rank, period: period, position: 97, name: "Sau khi discard")
      expect(new_rank.personnel_entries.where(contact_point: cp)).to be_empty
    end
  end
end
