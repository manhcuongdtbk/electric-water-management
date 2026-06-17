require "rails_helper"

RSpec.describe PeriodComparison do
  let(:sample) { setup_zone_one_full_sample }
  let(:user) { create(:user, :system_admin) }
  let(:ability) { Ability.new(user) }

  describe "#call — early return when no calculations exist (line 22)" do
    it "returns empty array when neither period has calculations" do
      period_a = sample.period
      period_b_result = begin
        period_a.update!(closed: true)
        PeriodService.new.open_new_period
      end
      period_b = period_b_result.period
      # No CalculationOrchestrator run => no calculations in either period
      rows = described_class.new(ability: ability, period_a: period_a, period_b: period_b).call
      expect(rows).to eq([])
    end
  end

  describe "#call — nil guards in sort_rows (lines 65-69)" do
    it "handles contact points with nil zone, unit, block, and group" do
      period_a = sample.period
      CalculationOrchestrator.new(zone: sample.zone, period: period_a).call

      period_a.update!(closed: true)
      period_b = PeriodService.new.open_new_period.period

      # Create a zone-direct residential CP (no unit, no block, no group)
      zone_cp = create(:contact_point, :zone_residential, name: "CP zone direct",
                       zone: sample.zone,
                       initial_personnel_counts: { period_b.ranks.first.id => 1 })
      zone_meter = create(:meter, name: "CT-ZD", contact_point: zone_cp, no_loss: false)
      zone_meter.meter_readings.find_by(period: period_b)
                .update!(reading_end: BigDecimal("50"))
      sample.main_meter.main_meter_readings.create!(period: period_b, usage: BigDecimal("2100"))
      sample.meters.each_value do |meter|
        reading = meter.meter_readings.find_by(period: period_b)
        reading&.update!(reading_end: (reading.reading_start || 0) + 100)
      end
      CalculationOrchestrator.new(zone: sample.zone, period: period_b).call

      rows = described_class.new(ability: ability, period_a: period_a, period_b: period_b).call
      # The zone-direct CP should appear with note "moi o ky..." and not crash on nil guards
      zone_row = rows.find { |r| r.contact_point&.name == "CP zone direct" }
      expect(zone_row).to be_present
      expect(zone_row.note).to include("mới ở kỳ")
    end
  end

  describe "#call" do
    context "2 kỳ cùng có data" do
      let(:period_a) { sample.period }
      let(:period_b) do
        CalculationOrchestrator.new(zone: sample.zone, period: period_a).call
        period_a.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        sample.meters[:ct_a1].meter_readings.find_by(period: new_period)
              .update!(reading_start: 1250, reading_end: 1350)
        sample.meters.each do |key, meter|
          next if key == :ct_a1
          attrs = SampleData::SAMPLE_METER_READINGS[key]
          delta = attrs[:finish] - attrs[:start]
          new_reading = meter.meter_readings.find_by(period: new_period)
          new_reading.update!(reading_start: new_reading.reading_start,
                              reading_end: new_reading.reading_start + delta,
                              no_loss: attrs[:no_loss])
        end
        sample.main_meter.main_meter_readings.create!(period: new_period, usage: 2100)
        CalculationOrchestrator.new(zone: sample.zone, period: new_period).call
        new_period
      end

      it "trả về Row cho mọi contact_point xuất hiện ở 2 kỳ" do
        rows = described_class.new(ability: ability, period_a: period_a, period_b: period_b).call
        expect(rows.size).to be >= 5
        rows.each do |row|
          expect(row).to be_a(described_class::Row)
        end
      end

      it "diff khác 0 khi data thay đổi" do
        rows = described_class.new(ability: ability, period_a: period_a, period_b: period_b).call
        ban_tac_huan_row = rows.find { |r| r.contact_point.name == "Ban Tác huấn" }
        expect(ban_tac_huan_row.diff).not_to be_nil
      end
    end

    context "đầu mối chỉ có ở 1 kỳ (T85)" do
      let(:period_a) { sample.period }
      let(:period_b) do
        CalculationOrchestrator.new(zone: sample.zone, period: period_a).call
        period_a.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        # Thêm contact_point "Lái xe" mới ở kỳ 6 (kèm công tơ — residential luôn có ≥ 1 công tơ)
        rank_id = new_period.ranks.first.id
        lai_xe = ContactPoint.create!(name: "Lái xe", contact_point_type: "residential",
                                      unit: sample.unit_a, block: nil, group: nil,
                                      initial_personnel_counts: { rank_id => 2 })
        lai_xe_meter = create(:meter, name: "CT-LX", contact_point: lai_xe, no_loss: false)
        lai_xe_meter.meter_readings.find_by(period: new_period)
                    .update!(reading_end: BigDecimal("100"))
        sample.main_meter.main_meter_readings.create!(period: new_period, usage: 2100)
        sample.meters.each do |key, meter|
          attrs = SampleData::SAMPLE_METER_READINGS[key]
          reading = meter.meter_readings.find_by(period: new_period)
          reading.update!(reading_start: reading.reading_start,
                          reading_end: reading.reading_start + (attrs[:finish] - attrs[:start]),
                          no_loss: attrs[:no_loss])
        end
        CalculationOrchestrator.new(zone: sample.zone, period: new_period).call
        new_period
      end

      it "Row của 'Lái xe' có note 'mới ở kỳ ...' và diff nil" do
        rows = described_class.new(ability: ability, period_a: period_a, period_b: period_b).call
        lai_xe = rows.find { |r| r.contact_point.name == "Lái xe" }
        expect(lai_xe).not_to be_nil
        expect(lai_xe.calc_a).to be_nil
        expect(lai_xe.calc_b).not_to be_nil
        expect(lai_xe.diff).to be_nil
        expect(lai_xe.note).to include("mới ở kỳ")
      end
    end
  end
end
