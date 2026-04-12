require "rails_helper"

RSpec.describe RankQuota, type: :model do
  describe "validations" do
    subject { build(:rank_quota) }

    it { is_expected.to validate_presence_of(:rank_group) }
    it { is_expected.to validate_presence_of(:rank_name) }
    it { is_expected.to validate_length_of(:rank_name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:quota_kw) }
    it { is_expected.to validate_presence_of(:effective_from) }
    it { is_expected.to validate_uniqueness_of(:rank_group).scoped_to(:effective_from) }

    it "rejects quota_kw <= 0" do
      expect(build(:rank_quota, quota_kw: 0)).not_to be_valid
      expect(build(:rank_quota, quota_kw: -10)).not_to be_valid
    end

    it "rejects invalid rank_group" do
      expect(build(:rank_quota, rank_group: 0)).not_to be_valid
      expect(build(:rank_quota, rank_group: 8)).not_to be_valid
    end

    it "accepts rank_groups 1..7" do
      (1..7).each do |group|
        expect(build(:rank_quota, rank_group: group)).to be_valid
      end
    end

    it "prevents duplicate rank_group for same effective_from" do
      create(:rank_quota, rank_group: 1, effective_from: Date.new(2024, 1, 1))
      dup = build(:rank_quota, rank_group: 1, effective_from: Date.new(2024, 1, 1))
      expect(dup).not_to be_valid
    end

    it "allows same rank_group with different effective_from" do
      create(:rank_quota, rank_group: 1, effective_from: Date.new(2024, 1, 1))
      newer = build(:rank_quota, rank_group: 1, effective_from: Date.new(2025, 1, 1))
      expect(newer).to be_valid
    end
  end

  describe ".effective_at" do
    let!(:old_quota) { create(:rank_quota, rank_group: 1, quota_kw: 500, effective_from: Date.new(2023, 1, 1)) }
    let!(:new_quota) { create(:rank_quota, rank_group: 1, quota_kw: 570, effective_from: Date.new(2024, 1, 1)) }

    it "returns most recent quota effective by given date" do
      result = RankQuota.for_rank(1).effective_at(Date.new(2024, 6, 1)).first
      expect(result).to eq(new_quota)
    end

    it "returns older quota before newer effective_from" do
      result = RankQuota.for_rank(1).effective_at(Date.new(2023, 6, 1)).first
      expect(result).to eq(old_quota)
    end
  end

  describe ".current_quotas_for" do
    before do
      (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
    end

    it "returns a hash with all 7 rank groups" do
      result = RankQuota.current_quotas_for(Date.new(2026, 1, 1))
      expect(result.keys.sort).to eq((1..7).to_a)
      expect(result[1]).to eq(570)
      expect(result[7]).to eq(24)
    end
  end
end
