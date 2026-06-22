require "rails_helper"

RSpec.describe PumpStationChargeWriter do
  # Dựng một khu vực per-trạm: 2 trạm, 2 recipient riêng. Σ per-trạm = D toàn khu vực.
  # (giống kịch bản CHIEU-phan-bo-tram-tong của PumpAllocationCalculator).
  def build_two_station_zone
    zone = create(:zone, name: "KV writer hai trạm")
    period = PeriodService.new.open_new_period(
      year: 2031, month: 1, unit_price: BigDecimal("2000")
    ).period
    rank = period.ranks.order(:position).first

    station_a = create(:contact_point, :water_pump, name: "Trạm A", zone: zone)
    station_b = create(:contact_point, :water_pump, name: "Trạm B", zone: zone)
    meter_a = create(:meter, name: "CT-A", contact_point: station_a, no_loss: true)
    meter_b = create(:meter, name: "CT-B", contact_point: station_b, no_loss: true)
    meter_a.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
    meter_b.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 60)

    unit_a = create(:unit, name: "ĐV A", zone: zone)
    cp_a = create(:contact_point, :residential, name: "Đầu mối A", unit: unit_a,
                  initial_personnel_counts: { rank.id => 1 })
    unit_b = create(:unit, name: "ĐV B", zone: zone)
    cp_b = create(:contact_point, :residential, name: "Đầu mối B", unit: unit_b,
                  initial_personnel_counts: { rank.id => 1 })

    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
           unit: unit_a, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)
    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_b,
           unit: unit_b, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

    OpenStruct.new(zone: zone, period: period, station_a: station_a, station_b: station_b,
                   cp_a: cp_a, cp_b: cp_b)
  end

  def run_orchestrator(ctx)
    CalculationOrchestrator.new(zone: ctx.zone, period: ctx.period).call
  end

  describe "qua CalculationOrchestrator — ghi pump_station_charges" do
    let(:ctx) { build_two_station_zone }

    it "ghi đúng một hàng non-zero cho mỗi (recipient, trạm)" do
      run_orchestrator(ctx)

      charges = PumpStationCharge.where(zone: ctx.zone, period: ctx.period)
      expect(charges.count).to eq(2)

      row_a = charges.find_by(contact_point: ctx.cp_a)
      expect(row_a.pump_contact_point_id).to eq(ctx.station_a.id)
      expect(row_a.amount).to eq(BigDecimal("100"))

      row_b = charges.find_by(contact_point: ctx.cp_b)
      expect(row_b.pump_contact_point_id).to eq(ctx.station_b.id)
      expect(row_b.amount).to eq(BigDecimal("60"))
    end

    it "idempotent: chạy lại thay thế hàng, không nhân đôi" do
      run_orchestrator(ctx)
      run_orchestrator(ctx)

      expect(PumpStationCharge.where(zone: ctx.zone, period: ctx.period).count).to eq(2)
    end
  end

  describe "nhánh legacy (gộp toàn khu vực) → không có per-trạm detail" do
    let(:sample) { setup_zone_one_full_sample } # pump_allocation_per_station: false

    it "không ghi pump_station_charges" do
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      expect(PumpStationCharge.where(zone: sample.zone, period: sample.period)).to be_empty
    end
  end

  describe "#call trực tiếp — chỉ ghi contribution non-zero" do
    let(:sample) { setup_zone_one_full_sample }
    let(:recipient) { sample.contact_points[:ban_tac_huan] }
    let(:station) { sample.contact_points[:tram_bom_1] }

    it "bỏ qua amount = 0, giữ amount > 0" do
      pump_results = PumpAllocationCalculator::Result.new(
        contact_point_allocations: {},
        contact_point_station_allocations: {
          recipient.id => { station.id => BigDecimal("12.5") },
          sample.contact_points[:van_thu].id => { station.id => BigDecimal("0") }
        },
        total_d: BigDecimal("12.5"), warnings: []
      )
      described_class.new(zone: sample.zone, period: sample.period, pump_results: pump_results).call

      charges = PumpStationCharge.where(zone: sample.zone, period: sample.period)
      expect(charges.count).to eq(1)
      expect(charges.first.amount).to eq(BigDecimal("12.5"))
    end
  end
end
