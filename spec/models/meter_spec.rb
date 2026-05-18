require "rails_helper"

RSpec.describe Meter do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to have_many(:meter_readings) }
  end

  describe "validations" do
    subject { build(:meter) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:contact_point_id) }
  end

  describe "#contact_point_type" do
    it "delegate xuống contact_point" do
      cp = create(:contact_point, :water_pump)
      meter = create(:meter, contact_point: cp)
      expect(meter.contact_point_type).to eq("water_pump")
    end
  end

  describe "scope :in_zone" do
    it "trả về meter của contact_points trong zone" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      cp = create(:contact_point, :residential, unit: unit)
      meter = create(:meter, contact_point: cp)
      other_meter = create(:meter)

      expect(Meter.in_zone(zone)).to include(meter)
      expect(Meter.in_zone(zone)).not_to include(other_meter)
    end
  end

  describe "discard" do
    it "có scope kept" do
      expect(Meter).to respond_to(:kept)
    end
  end

  describe "auto-snapshot khi tạo meter lúc kỳ đang mở" do
    context "khi không có kỳ đang mở" do
      it "không tạo meter_reading" do
        meter = create(:meter)
        expect(meter.meter_readings).to be_empty
      end
    end

    context "khi kỳ đang mở" do
      let!(:period) { create(:period, closed: false) }

      it "tạo meter_reading với reading_start=0, reading_end=nil, no_loss từ meter" do
        meter = create(:meter, no_loss: true)
        reading = meter.meter_readings.find_by(period: period)
        expect(reading).to be_present
        expect(reading.reading_start).to eq(0)
        expect(reading.reading_end).to be_nil
        expect(reading.no_loss).to be true
      end

      it "no_loss=false khi meter no_loss=false" do
        meter = create(:meter, no_loss: false)
        reading = meter.meter_readings.find_by(period: period)
        expect(reading.no_loss).to be false
      end
    end
  end
end
