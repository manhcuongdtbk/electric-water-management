require "rails_helper"

RSpec.describe PeriodInheritanceService do
  let(:division)   { create(:organization, level: :division, parent: nil) }
  let(:org)        { create(:organization, level: :unit, parent: division) }
  let!(:cp1)       { create(:contact_point, organization: org) }
  let!(:cp2)       { create(:contact_point, organization: org) }

  # Periods ordered chronologically
  let!(:period_jan) { create(:monthly_period, year: 2026, month: 1) }
  let!(:period_feb) { create(:monthly_period, year: 2026, month: 2) }

  describe "#call" do
    context "when a previous period exists with personnel records" do
      let!(:jan_p1) do
        create(:personnel, contact_point: cp1, monthly_period: period_jan,
               rank1_count: 2, rank2_count: 5, rank7_count: 10)
      end
      let!(:jan_p2) do
        create(:personnel, contact_point: cp2, monthly_period: period_jan,
               rank1_count: 1, rank7_count: 20)
      end

      subject { described_class.new(period_feb).call }

      it "returns the count of inherited records" do
        expect(subject).to eq(2)
      end

      it "creates personnel records for the new period" do
        subject
        expect(Personnel.for_period(period_feb.id).count).to eq(2)
      end

      it "copies rank values from the previous period" do
        subject
        inherited = Personnel.find_by(contact_point: cp1, monthly_period: period_feb)
        expect(inherited.rank1_count).to eq(jan_p1.rank1_count)
        expect(inherited.rank2_count).to eq(jan_p1.rank2_count)
        expect(inherited.rank7_count).to eq(jan_p1.rank7_count)
      end

      it "leaves reviewed_at nil on inherited records" do
        subject
        inherited = Personnel.find_by(contact_point: cp1, monthly_period: period_feb)
        expect(inherited.reviewed_at).to be_nil
      end

      it "does not overwrite existing records for the new period" do
        existing = create(:personnel, contact_point: cp1, monthly_period: period_feb,
                          rank7_count: 99)
        subject
        existing.reload
        expect(existing.rank7_count).to eq(99)
      end

      it "does not modify the source (previous) period records" do
        subject
        jan_p1.reload
        expect(jan_p1.rank1_count).to eq(2)
        expect(jan_p1.rank7_count).to eq(10)
      end
    end

    context "when no previous period exists" do
      subject { described_class.new(period_jan).call }

      it "returns 0" do
        expect(subject).to eq(0)
      end

      it "creates no personnel records" do
        expect { subject }.not_to change(Personnel, :count)
      end
    end

    context "when the previous period has no personnel records" do
      subject { described_class.new(period_feb).call }

      it "returns 0" do
        expect(subject).to eq(0)
      end
    end

    context "when there is a non-adjacent earlier period" do
      let!(:period_dec) { create(:monthly_period, year: 2025, month: 12) }
      let!(:dec_p1) do
        create(:personnel, contact_point: cp1, monthly_period: period_dec,
               rank7_count: 50)
      end

      it "inherits from the immediately preceding period (Jan), not Dec" do
        create(:personnel, contact_point: cp1, monthly_period: period_jan,
               rank7_count: 30)
        described_class.new(period_feb).call
        inherited = Personnel.find_by(contact_point: cp1, monthly_period: period_feb)
        expect(inherited.rank7_count).to eq(30)
      end
    end
  end
end
