require "rails_helper"

RSpec.describe MainMeter, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:organizations) }
    it { is_expected.to have_many(:main_meter_readings).dependent(:destroy) }
    it { is_expected.to have_many(:monthly_periods).through(:main_meter_readings) }
  end

  describe "validations" do
    subject { build(:main_meter) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "allows blank notes" do
      expect(build(:main_meter, notes: nil)).to be_valid
      expect(build(:main_meter, notes: "")).to be_valid
    end

    it "rejects negative position" do
      expect(build(:main_meter, position: -1)).not_to be_valid
    end
  end

  describe "scopes" do
    describe ".ordered" do
      it "orders by position then name" do
        third  = create(:main_meter, name: "A", position: 3)
        first  = create(:main_meter, name: "B", position: 1)
        second = create(:main_meter, name: "C", position: 2)
        expect(described_class.ordered).to eq([ first, second, third ])
      end
    end
  end

  describe "#reading_for / #supply_kw_for" do
    let(:main_meter) { create(:main_meter) }
    let(:period)     { create(:monthly_period) }
    let!(:reading)   { create(:main_meter_reading, main_meter: main_meter, monthly_period: period, electricity_supply_kw: 4567) }

    it "returns the matching reading" do
      expect(main_meter.reading_for(period)).to eq(reading)
    end

    it "returns the supply kw value" do
      expect(main_meter.supply_kw_for(period)).to eq(4567)
    end

    it "returns nil when there is no reading for the period" do
      other_period = create(:monthly_period, year: 2030, month: 1)
      expect(main_meter.reading_for(other_period)).to be_nil
      expect(main_meter.supply_kw_for(other_period)).to be_nil
    end
  end

  describe "papertrail" do
    it "records versions on update" do
      mm = create(:main_meter)
      expect { mm.update!(name: "Renamed") }.to change { PaperTrail::Version.where(item: mm).count }.by(1)
    end
  end

  describe "organization detachment on destroy" do
    it "nullifies organizations linked to it" do
      mm  = create(:main_meter)
      div = create(:organization, :division)
      org = create(:organization, :unit, parent: div, main_meter: mm)
      mm.destroy!
      expect(org.reload.main_meter_id).to be_nil
    end

    it "records a paper_trail version on each detached organization" do
      mm  = create(:main_meter)
      div = create(:organization, :division)
      org = create(:organization, :unit, parent: div, main_meter: mm)
      expect { mm.destroy! }
        .to change { PaperTrail::Version.where(item_type: "Organization", item_id: org.id).count }.by(1)
    end
  end
end
