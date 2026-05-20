require "rails_helper"

RSpec.describe MainMeter do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to have_many(:main_meter_readings) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "discard" do
    it "có scope kept" do
      expect(MainMeter).to respond_to(:kept)
    end
  end

  describe "before_discard :delete_current_period_main_meter_readings (cleanup data kỳ đang mở v2.4.0)" do
    context "khi có kỳ đang mở" do
      let!(:period) { create(:period, closed: false) }

      it "discard công tơ tổng → xóa main_meter_reading kỳ đang mở" do
        zone = create(:zone)
        main_meter = zone.main_meters.first
        create(:main_meter_reading, main_meter: main_meter, period: period)

        expect(MainMeterReading.where(main_meter: main_meter, period: period)).to be_present
        expect(main_meter.discard).to be true
        expect(MainMeterReading.where(main_meter: main_meter, period: period)).to be_empty
      end

      it "giữ nguyên main_meter_reading kỳ cũ (đã đóng)" do
        old_period = create(:period, closed: true)
        zone = create(:zone)
        main_meter = zone.main_meters.first
        old_reading = create(:main_meter_reading, main_meter: main_meter, period: old_period)
        create(:main_meter_reading, main_meter: main_meter, period: period)

        main_meter.discard

        expect(MainMeterReading.where(main_meter: main_meter, period: period)).to be_empty
        expect(MainMeterReading.where(id: old_reading.id)).to be_present
      end

      it "discard khu vực vẫn cascade discard công tơ tổng và dọn reading kỳ đang mở" do
        zone = create(:zone)
        main_meter = zone.main_meters.first
        create(:main_meter_reading, main_meter: main_meter, period: period)

        expect(zone.discard).to be true
        expect(main_meter.reload).to be_discarded
        expect(MainMeterReading.where(main_meter: main_meter, period: period)).to be_empty
      end
    end

    context "khi không có kỳ đang mở" do
      it "discard công tơ tổng → không xóa main_meter_reading kỳ cũ" do
        old_period = create(:period, closed: true)
        zone = create(:zone)
        main_meter = zone.main_meters.first
        old_reading = create(:main_meter_reading, main_meter: main_meter, period: old_period)

        main_meter.discard

        expect(MainMeterReading.where(id: old_reading.id)).to be_present
      end
    end
  end
end
