require "rails_helper"

RSpec.describe Personnel, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "validations" do
    subject { build(:personnel) }

    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:monthly_period_id) }

    (1..7).each do |i|
      it { is_expected.to validate_numericality_of(:"rank#{i}_count").only_integer.is_greater_than_or_equal_to(0) }
    end

    it "prevents duplicate contact_point in same period" do
      cp = create(:contact_point)
      period = create(:monthly_period, month: 1)
      create(:personnel, contact_point: cp, monthly_period: period)
      dup = build(:personnel, contact_point: cp, monthly_period: period)
      expect(dup).not_to be_valid
    end
  end

  describe "scopes" do
    it ".by_organization filters by contact_point's organization" do
      org = create(:organization)
      cp = create(:contact_point, organization: org)
      p1 = create(:personnel, contact_point: cp)
      p2 = create(:personnel)
      expect(Personnel.by_organization(org.id)).to include(p1)
      expect(Personnel.by_organization(org.id)).not_to include(p2)
    end
  end

  describe "#total_count" do
    it "sums all rank counts" do
      p = build(:personnel,
                rank1_count: 1, rank2_count: 2, rank3_count: 3,
                rank4_count: 4, rank5_count: 0, rank6_count: 1, rank7_count: 0)
      expect(p.total_count).to eq(11)
    end
  end
end
