require "rails_helper"

RSpec.describe ImportFeb2026Service do
  let(:division) { create(:organization, :division, code: "SD", name: "Sư đoàn") }
  let!(:sdb)     { create(:organization, code: "SDB", name: "Sư đoàn bộ", parent: division, level: :unit) }

  before do
    RankQuota::STANDARD_QUOTAS.each do |group, kw|
      RankQuota.find_or_create_by!(rank_group: group, effective_from: Date.new(2024, 1, 1)) do |rq|
        rq.rank_name = "Group #{group}"
        rq.quota_kw  = kw
      end
    end
  end

  subject(:result) { described_class.new.call }

  describe "#call" do
    it "creates the monthly period 2026-02 with the Excel unit price" do
      result
      period = MonthlyPeriod.find_by(year: 2026, month: 2)
      expect(period.unit_price).to eq(BigDecimal("2336.4"))
      expect(period.locked).to be(false)
    end

    it "creates a UnitConfig for SDB with the decided electricity supply and rates" do
      result
      cfg = UnitConfig.find_by!(organization: sdb, monthly_period: MonthlyPeriod.last)
      expect(cfg.electricity_supply_kw).to eq(BigDecimal("41940"))
      expect(cfg.savings_rate).to eq(BigDecimal("0.05"))
      expect(cfg.division_public_rate).to eq(BigDecimal("0.10"))
      expect(cfg.unit_public_rate).to eq(BigDecimal("0"))
    end

    it "imports all 79 contact points grouped across 4 sections" do
      result
      cps = ContactPoint.where(organization: sdb)
      expect(cps.count).to eq(79)
      sections = cps.pluck(:group_name).uniq
      expect(sections).to contain_exactly(
        "I. Phòng Tham mưu",
        "II. Phòng chính trị",
        "III. Phòng HC-KT",
        "IV. Khác"
      )
    end

    it "maps Excel rank columns to the v5 rank buckets (E→rank1, F+G→rank5, H→rank7)" do
      result
      ban_tac_huan = ContactPoint.find_by(organization: sdb, name: "Ban Tác Huấn — Trưởng ban + QUÝ")
      p = Personnel.find_by!(contact_point: ban_tac_huan, monthly_period: MonthlyPeriod.last)

      expect(p.rank1_count).to eq(0)
      expect(p.rank5_count).to eq(2) # F=2, G=0
      expect(p.rank7_count).to eq(0)
      expect(p.rank2_count).to eq(0)
      expect(p.rank3_count).to eq(0)
      expect(p.rank4_count).to eq(0)
      expect(p.rank6_count).to eq(0)
    end

    it "aggregates Nhà ở + NLV columns into a single MeterReading per contact point" do
      result
      tmp_truong = ContactPoint.find_by!(organization: sdb, name: "TMP Trường")
      meter = Meter.find_by!(contact_point: tmp_truong)
      reading = MeterReading.find_by!(meter: meter, monthly_period: MonthlyPeriod.last)

      # Sheet1 R22: Nhà ở 13223→13322, NLV 87→87. Start=13310, End=13409, Consumption=99.
      expect(reading.reading_start).to eq(BigDecimal("13310"))
      expect(reading.reading_end).to   eq(BigDecimal("13409"))
      expect(reading.consumption).to   eq(BigDecimal("99"))
    end

    it "stores the negative 'Khác' for Bảo đảm via save(validate: false) and emits a warning" do
      res = result
      bao_dam = ContactPoint.find_by!(organization: sdb, name: "Bảo đảm (Không tính quân y f bộ)")
      ded = ContactPointOtherDeduction.find_by!(contact_point: bao_dam, monthly_period: MonthlyPeriod.last)

      expect(ded.other_value).to eq(BigDecimal("-296"))
      expect(ded.other_type).to eq("fixed_kw")
      expect(res.warnings).to include(match(/Bảo đảm.*-296.*bypass validation/))
    end

    it "creates 3 pump stations, each with a pump_station meter assigned to SDB, summing ≈ 6,152 kW raw" do
      result
      expect(PumpStation.where(organization: sdb).count).to eq(3)
      expect(PumpStationAssignment.where(organization: sdb).count).to eq(3)

      pump_meters = Meter.where(organization: sdb, meter_type: :pump_station)
      expect(pump_meters.count).to eq(3)

      total = MeterReading.where(meter: pump_meters, monthly_period: MonthlyPeriod.last).sum(:consumption)
      # Sheet1 rows 145+146+147 raw usage: 3086+2158+908 = 6152 (before loss allocation)
      expect(total).to eq(BigDecimal("6152"))
    end

    it "emits the no_loss_position and Bảng II warnings" do
      expect(result.warnings).to include(match(/no_loss_position chưa support/))
      expect(result.warnings).to include(match(/Bảng II bỏ qua/))
    end

    it "is idempotent — running twice does not change record counts" do
      described_class.new.call
      counts_before = {
        cp:   ContactPoint.count,
        m:    Meter.count,
        mr:   MeterReading.count,
        p:    Personnel.count,
        dedu: ContactPointOtherDeduction.count,
        ps:   PumpStation.count,
        psa:  PumpStationAssignment.count,
        uc:   UnitConfig.count,
        mp:   MonthlyPeriod.count
      }

      described_class.new.call

      counts_after = {
        cp:   ContactPoint.count,
        m:    Meter.count,
        mr:   MeterReading.count,
        p:    Personnel.count,
        dedu: ContactPointOtherDeduction.count,
        ps:   PumpStation.count,
        psa:  PumpStationAssignment.count,
        uc:   UnitConfig.count,
        mp:   MonthlyPeriod.count
      }

      expect(counts_after).to eq(counts_before)
    end

    it "does not create PaperTrail versions on re-run with identical data" do
      described_class.new.call
      versions_before = PaperTrail::Version.count

      described_class.new.call
      versions_after = PaperTrail::Version.count

      expect(versions_after).to eq(versions_before)
    end

    context "when the period 2026-02 is already locked" do
      before do
        locker = create(:user, role: :admin_level1, organization: division)
        MonthlyPeriod.create!(year: 2026, month: 2, unit_price: BigDecimal("2336.4"),
                              locked: true, locked_at: Time.current, locked_by: locker)
      end

      it "refuses to import and rolls back any partial state" do
        expect { described_class.new.call }.to raise_error(/locked period/)
        expect(ContactPoint.count).to eq(0)
      end
    end

    it "returns a Result struct populated with imported counts" do
      expect(result).to have_attributes(
        contact_points_count: 79,
        meters_count: 82, # 79 contact meters + 3 pump meters
        readings_count: 82,
        personnel_count: 79,
        pump_stations_count: 3
      )
      expect(result.other_deductions_count).to be >= 60
    end

    it "produces data that the CalculationEngine can consume without error" do
      result
      period = MonthlyPeriod.find_by(year: 2026, month: 2)
      engine = CalculationEngine.new(organization: sdb, monthly_period: period)
      results = engine.call
      expect(results.length).to eq(79)

      tmp = results.find do |r|
        ContactPoint.find(r[:contact_point_id]).name == "TMP Trường"
      end
      # TMP Trường: rank1_count=1 → total_standard = 570 + 9.45 = 579.45 (v5 engine, not Excel's 121.3)
      expect(tmp[:total_standard_kw]).to eq(BigDecimal("579.45"))
      expect(tmp[:meter_usage_kw]).to eq(BigDecimal("99"))
    end

    context "when the Excel fixture is missing" do
      it "raises ArgumentError without any DB writes" do
        expect do
          described_class.new(path: "nonexistent.xlsx").call
        end.to raise_error(ArgumentError, /Excel file not found/)

        expect(ContactPoint.count).to eq(0)
        expect(MonthlyPeriod.count).to eq(0)
      end
    end

    context "when the organization SDB does not exist" do
      before { sdb.destroy! }

      it "raises RecordNotFound without creating partial records" do
        expect do
          described_class.new.call
        end.to raise_error(ActiveRecord::RecordNotFound)

        expect(ContactPoint.count).to eq(0)
        # MonthlyPeriod is created before org lookup inside the txn,
        # so the txn rollback must un-create it.
        expect(MonthlyPeriod.count).to eq(0)
      end
    end
  end
end
