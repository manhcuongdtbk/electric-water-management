require "rails_helper"

RSpec.describe RankQuota, type: :model do
  describe "validations" do
    subject { build(:rank_quota) }

    it { is_expected.to validate_presence_of(:rank_group) }
    it { is_expected.to validate_presence_of(:rank_name) }
    it { is_expected.to validate_length_of(:rank_name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:quota_kw) }
    it { is_expected.to validate_uniqueness_of(:rank_group) }

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

    it "prevents duplicate rank_group" do
      create(:rank_quota, rank_group: 1)
      dup = build(:rank_quota, rank_group: 1)
      expect(dup).not_to be_valid
    end
  end

  describe ".current_quotas" do
    before do
      (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
    end

    it "returns a hash with all 7 rank groups" do
      result = RankQuota.current_quotas
      expect(result.keys.sort).to eq((1..7).to_a)
      expect(result[1]).to eq(570)
      expect(result[7]).to eq(24)
    end
  end

  describe ".current_names" do
    before do
      (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
    end

    it "returns a hash with keys 1..7" do
      result = RankQuota.current_names
      expect(result.keys.sort).to eq((1..7).to_a)
    end

    it "returns rank_name from existing record" do
      RankQuota.where(rank_group: 1).delete_all
      create(:rank_quota, rank_group: 1, rank_name: "Ten moi", quota_kw: 570)
      result = RankQuota.current_names
      expect(result[1]).to eq("Ten moi")
    end

    it "falls back to 'Nhóm N' when no record exists for a group" do
      RankQuota.where(rank_group: 3).delete_all
      result = RankQuota.current_names
      expect(result[3]).to eq("Nhóm 3")
    end
  end
end
