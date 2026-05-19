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

  describe "propagate_no_loss khi update meter.no_loss" do
    let!(:period) { create(:period, closed: false) }
    let!(:meter) { create(:meter, no_loss: false) }

    it "cập nhật meter_reading của kỳ đang mở khi đổi no_loss" do
      reading = meter.meter_readings.find_by(period: period)
      expect(reading.no_loss).to be false
      meter.update!(no_loss: true)
      expect(reading.reload.no_loss).to be true
    end

    it "không lỗi khi không có kỳ đang mở" do
      period.update!(closed: true)
      expect { meter.update!(no_loss: true) }.not_to raise_error
    end
  end

  describe "before_discard :ensure_not_last_meter (T38)" do
    let(:cp) { create(:contact_point, :residential) }

    it "chặn discard meter cuối cùng của contact_point residential" do
      meter = create(:meter, contact_point: cp)
      expect(meter.discard).to be false
      expect(meter.errors[:base]).to include(
        I18n.t("activerecord.errors.models.meter.attributes.base.last_meter_cannot_be_destroyed")
      )
    end

    it "cho discard nếu còn meter khác" do
      meter1 = create(:meter, contact_point: cp, name: "M1")
      _meter2 = create(:meter, contact_point: cp, name: "M2")
      expect(meter1.discard).to be true
      expect(meter1.reload).to be_discarded
    end
  end

  describe "before_discard :delete_current_period_meter_readings (cleanup data kỳ đang mở v2.4.0)" do
    context "khi có kỳ đang mở" do
      let!(:period) { create(:period, closed: false) }

      it "discard công tơ đơn lẻ → xóa meter_reading kỳ đang mở" do
        cp = create(:contact_point, :residential)
        meter1 = create(:meter, contact_point: cp, name: "M1")
        create(:meter, contact_point: cp, name: "M2")

        expect(MeterReading.where(meter: meter1, period: period)).to be_present
        expect(meter1.discard).to be true
        expect(MeterReading.where(meter: meter1, period: period)).to be_empty
      end

      it "không xóa meter_reading kỳ cũ (đã đóng)" do
        old_period = create(:period, year: 2025, month: 12, closed: true)
        cp = create(:contact_point, :residential)
        meter1 = create(:meter, contact_point: cp, name: "M1")
        create(:meter, contact_point: cp, name: "M2")
        old_reading = create(:meter_reading, meter: meter1, period: old_period)

        meter1.discard

        expect(MeterReading.where(meter: meter1, period: period)).to be_empty
        expect(MeterReading.where(id: old_reading.id)).to be_present
      end
    end

    context "khi không có kỳ đang mở" do
      it "discard công tơ → không xóa meter_reading kỳ cũ" do
        old_period = create(:period, closed: true)
        cp = create(:contact_point, :residential)
        meter1 = create(:meter, contact_point: cp, name: "M1")
        create(:meter, contact_point: cp, name: "M2")
        old_reading = create(:meter_reading, meter: meter1, period: old_period)

        meter1.discard

        expect(MeterReading.where(id: old_reading.id)).to be_present
      end
    end
  end
end
