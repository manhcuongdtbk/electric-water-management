require "rails_helper"

RSpec.describe PeriodService do
  subject(:service) { described_class.new }

  describe "#open_new_period — kỳ đầu tiên (T19)" do
    let!(:zone) { create(:zone) }
    let!(:unit) { create(:unit, zone: zone) }

    it "tạo period với year/month chỉ định và 7 ranks mặc định" do
      result = service.open_new_period(year: 2026, month: 5, unit_price: BigDecimal("2336.4"))
      period = result.period

      expect(period.year).to eq(2026)
      expect(period.month).to eq(5)
      expect(period.closed).to be false
      expect(period.unit_price).to eq(BigDecimal("2336.4"))
      expect(period.savings_rate).to eq(BigDecimal("5"))
      expect(period.division_public_rate).to eq(BigDecimal("10"))
      expect(period.water_pump_standard).to eq(BigDecimal("9.45"))

      expect(period.ranks.count).to eq(7)
      quotas = period.ranks.order(:position).pluck(:quota)
      expect(quotas).to eq([570, 440, 305, 130, 210, 110, 24].map { |q| BigDecimal(q.to_s) })
    end

    it "tạo unit_configs mặc định 0% cho unit đã có" do
      result = service.open_new_period(year: 2026, month: 5, unit_price: 2336.4)
      config = unit.unit_configs.find_by(period: result.period)
      expect(config.unit_public_rate).to eq(0)
    end

    it "tạo meter_readings cho meter đã có với reading_start=0, no_loss từ meter" do
      cp = create(:contact_point, :residential, unit: unit)
      meter = create(:meter, contact_point: cp, no_loss: true)
      result = service.open_new_period(year: 2026, month: 5, unit_price: 2336.4)
      reading = meter.meter_readings.find_by(period: result.period)
      expect(reading.reading_start).to eq(0)
      expect(reading.reading_end).to be_nil
      expect(reading.no_loss).to be true
    end

    it "tạo non_establishment_snapshots dùng personnel_count từ contact_point" do
      cp = create(:contact_point, :non_establishment, zone: zone, personnel_count: 5)
      result = service.open_new_period(year: 2026, month: 5, unit_price: 2336.4)
      snapshot = cp.non_establishment_snapshots.find_by(period: result.period)
      expect(snapshot.personnel_count).to eq(5)
    end

    it "raise nếu thiếu year/month/unit_price ở kỳ đầu tiên" do
      expect { service.open_new_period(year: nil, month: 5, unit_price: 100) }
        .to raise_error(PeriodService::Error)
      expect { service.open_new_period(year: 2026, month: nil, unit_price: 100) }
        .to raise_error(PeriodService::Error)
      expect { service.open_new_period(year: 2026, month: 5, unit_price: nil) }
        .to raise_error(PeriodService::Error)
    end
  end

  describe "#open_new_period — kỳ kế tiếp (T20)" do
    let(:sample) { setup_zone_one_full_sample }

    it "tự xác định year/month = kỳ trước + 1 tháng" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      expect(result.period.year).to eq(2026)
      expect(result.period.month).to eq(6)
    end

    it "kế thừa unit_price, savings_rate, division_public_rate, water_pump_standard" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      expect(result.period.unit_price).to eq(sample.period.unit_price)
      expect(result.period.savings_rate).to eq(sample.period.savings_rate)
      expect(result.period.division_public_rate).to eq(sample.period.division_public_rate)
      expect(result.period.water_pump_standard).to eq(sample.period.water_pump_standard)
    end

    it "kế thừa ranks (name + quota + position)" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      old_ranks = sample.period.ranks.order(:position).pluck(:name, :quota, :position)
      new_ranks = result.period.ranks.order(:position).pluck(:name, :quota, :position)
      expect(new_ranks).to eq(old_ranks)
    end

    it "meter_readings.reading_start = reading_end kỳ trước" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      reading = sample.meters[:ct_a1].meter_readings.find_by(period: result.period)
      expect(reading.reading_start).to eq(BigDecimal("1250"))
      expect(reading.reading_end).to be_nil
    end

    it "personnel_entries.count kế thừa từ kỳ trước (match qua position)" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      cp = sample.contact_points[:ban_tac_huan]

      old_ha_si_quan = sample.period.ranks.find_by(position: 7)
      new_ha_si_quan = result.period.ranks.find_by(position: 7)
      old_entry = PersonnelEntry.find_by(contact_point: cp, period: sample.period, rank: old_ha_si_quan)
      new_entry = PersonnelEntry.find_by(contact_point: cp, period: result.period, rank: new_ha_si_quan)
      expect(new_entry.count).to eq(old_entry.count)
    end

    it "unit_configs.unit_public_rate kế thừa" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      config = sample.unit_a.unit_configs.find_by(period: result.period)
      expect(config.unit_public_rate).to eq(BigDecimal("3"))
    end

    it "other_deductions kế thừa other_type + other_value" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      deduction = sample.contact_points[:van_thu].other_deductions.find_by(period: result.period)
      expect(deduction.other_type).to eq("coefficient")
      expect(deduction.other_value).to eq(BigDecimal("-2.5"))
    end

    it "pump_allocations kế thừa cấu hình" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      expect(result.period.pump_allocations.count).to eq(sample.period.pump_allocations.count)
      chi_huy = result.period.pump_allocations.find_by(contact_point: sample.contact_points[:chi_huy_khu_vuc])
      expect(chi_huy.fixed_percentage).to eq(BigDecimal("20"))
    end

    it "KHÔNG kế thừa main_meter_readings (nhập mới)" do
      sample.period.update!(closed: true)
      result = service.open_new_period
      expect(MainMeterReading.where(period: result.period)).to be_empty
    end

    it "KHÔNG kế thừa calculations (tính mới)" do
      create(:calculation, contact_point: sample.contact_points[:ban_tac_huan], period: sample.period)
      sample.period.update!(closed: true)
      result = service.open_new_period
      expect(Calculation.where(period: result.period)).to be_empty
    end
  end

  describe "#open_new_period — chặn khi có kỳ đang mở (T21)" do
    it "raise Error" do
      create(:period, year: 2026, month: 5, closed: false)
      expect { service.open_new_period(year: 2026, month: 6, unit_price: 100) }
        .to raise_error(PeriodService::Error, /tháng 5\/2026 đang mở/)
    end
  end

  describe "#open_new_period — tháng 12 → tháng 1 năm sau (T24)" do
    it "tăng year, month = 1" do
      create(:period, year: 2026, month: 12, closed: true, unit_price: 100)
      result = service.open_new_period
      expect(result.period.year).to eq(2027)
      expect(result.period.month).to eq(1)
    end
  end

  describe "#close_period (T22, T23)" do
    let(:sample) { setup_zone_one_full_sample }

    it "đặt closed = true" do
      result = service.close_period(sample.period)
      expect(result.period.reload.closed).to be true
    end

    it "không cảnh báo khi không có kỳ kế tiếp" do
      result = service.close_period(sample.period)
      expect(result.warnings).to be_empty
    end

    it "cảnh báo khi số cuối kỳ không khớp số đầu kỳ kế tiếp (T23)" do
      sample.period.update!(closed: true)
      next_result = service.open_new_period
      next_period = next_result.period
      service.close_period(next_period)

      service.reopen_period(sample.period)
      reading = sample.meters[:ct_a1].meter_readings.find_by(period: sample.period)
      reading.update!(reading_end: BigDecimal("1300"))

      result = service.close_period(sample.period)
      expect(result.warnings.size).to eq(1)
      expect(result.warnings.first).to include("CT-A1", "1300", "1250")
    end
  end

  describe "#reopen_period (T14)" do
    let(:closed_period) { create(:period, year: 2026, month: 5, closed: true) }

    it "đặt closed = false khi không có kỳ nào đang mở" do
      reopened = service.reopen_period(closed_period)
      expect(reopened.reload.closed).to be false
    end

    it "raise Error khi có kỳ khác đang mở" do
      create(:period, year: 2026, month: 6, closed: false)
      expect { service.reopen_period(closed_period) }
        .to raise_error(PeriodService::Error, /tháng 6\/2026 đang mở/)
    end
  end
end
