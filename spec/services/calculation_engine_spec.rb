require "rails_helper"

# F08 + F09 + F10 — Engine tính toán bảng 22 cột.
#
# Per nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html + docs/BANG_22_COT_ANALYSIS.md):
#
#   * Water pump standard uses 9.45 kW/person/month
#   * Loss (tổn hao) is subtracted from standard, NOT added to usage
#   * Loss is zone-wide (per shared MainMeter), with pump in B:
#       B = Σ(normal + public_meter) in zone + Σ pump serving zone
#       total_zone_loss = supply − Σ no_loss − B
#       cp_loss = total_zone_loss × (cp_meter_kW / B)
#       pump_loss_share = total_zone_loss × (pump_kW / B)  → inflates pump pool
#
# All arithmetic is done in BigDecimal with NO rounding in intermediate steps.
RSpec.describe CalculationEngine do
  # -----------------------------------------------------------------------
  # Shorthands
  # -----------------------------------------------------------------------
  def bd(value) = BigDecimal(value.to_s)

  # -----------------------------------------------------------------------
  # Business constants (match the real app)
  # -----------------------------------------------------------------------
  let(:water_pump_rate) { bd("9.45") }      # v5: tiêu chuẩn bơm nước
  let(:savings_rate)    { bd("0.05") }      # 5%
  let(:div_public_rate) { bd("0.10") }      # 10% — công cộng Sư đoàn
  let(:unit_public_rate) { bd("0") }        # Excel tháng 02 không có CC đơn vị
  let(:unit_price)      { bd("2336.4") }    # giá kW tháng 02/2026

  # -----------------------------------------------------------------------
  # Test fixture — 3 đầu mối từ Excel "Sheet1 (2)"
  #   TMP Trường: 1 người cấp 3★/4★ (115 kW)
  #   TB Q.Lực:   1 người cấp 1★/2★ (38 kW) + 1 HSQ-CS (11 kW)
  #   Ban Tác Huấn: 2 người cấp 1★/2★ (2 × 38 = 76 kW)
  #
  #   (Excel dùng 4 nhóm 115/38/28/11; test map sang rank_group 1..4
  #    với RankQuota seed tương ứng để engine sinh ra đúng số sinh hoạt.)
  # -----------------------------------------------------------------------
  let(:division)    { create(:organization, :division) }
  let(:main_meter)  { create(:main_meter, name: "Zone fixture") }
  let(:organization) { create(:organization, level: :unit, parent: division, main_meter: main_meter) }
  let(:period)      { create(:monthly_period, year: 2026, month: 2, unit_price: unit_price) }
  let!(:main_meter_reading) do
    create(:main_meter_reading,
           main_meter: main_meter, monthly_period: period,
           electricity_supply_kw: bd("1800"))
  end

  let!(:rank_quota1) { create(:rank_quota, rank_group: 1, rank_name: "3*/4*",   quota_kw: bd("115")) }
  let!(:rank_quota2) { create(:rank_quota, rank_group: 2, rank_name: "1*/2*",   quota_kw: bd("38")) }
  let!(:rank_quota3) { create(:rank_quota, rank_group: 3, rank_name: "Cap uy",  quota_kw: bd("28")) }
  let!(:rank_quota4) { create(:rank_quota, rank_group: 4, rank_name: "HSQ-CS",  quota_kw: bd("11")) }

  let!(:cp_truong)    { create(:contact_point, organization: organization, name: "TMP Truong",   position: 1) }
  let!(:cp_qluc)      { create(:contact_point, organization: organization, name: "TB Q.Luc",     position: 2) }
  let!(:cp_tac_huan)  { create(:contact_point, organization: organization, name: "Ban Tac Huan", position: 3) }

  # Personnel — Excel columns E/F/G/H mapped to rank 1..4
  let!(:p_truong)   { create(:personnel, contact_point: cp_truong,   monthly_period: period, rank1_count: 1, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }
  let!(:p_qluc)     { create(:personnel, contact_point: cp_qluc,     monthly_period: period, rank1_count: 0, rank2_count: 1, rank3_count: 0, rank4_count: 1, rank5_count: 0, rank6_count: 0, rank7_count: 0) }
  let!(:p_tac_huan) { create(:personnel, contact_point: cp_tac_huan, monthly_period: period, rank1_count: 0, rank2_count: 2, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # Meter readings (normal) — one per contact point. Arbitrary but realistic.
  let!(:meter_truong)   { create(:meter, :normal, organization: organization, contact_point: cp_truong,   name: "M-Truong") }
  let!(:meter_qluc)     { create(:meter, :normal, organization: organization, contact_point: cp_qluc,     name: "M-QLuc") }
  let!(:meter_tac_huan) { create(:meter, :normal, organization: organization, contact_point: cp_tac_huan, name: "M-TacHuan") }

  let!(:reading_truong)   { create(:meter_reading, meter: meter_truong,   monthly_period: period, reading_start: 0, reading_end: 99,  consumption: 99) }
  let!(:reading_qluc)     { create(:meter_reading, meter: meter_qluc,     monthly_period: period, reading_start: 0, reading_end: 105, consumption: 105) }
  let!(:reading_tac_huan) { create(:meter_reading, meter: meter_tac_huan, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500) }

  # Pump station — 1 trạm bơm phục vụ organization, tổng điện 1000 kW.
  let!(:pump_station) { create(:pump_station, organization: division, name: "TB 1") }
  let!(:pump_meter)  { create(:meter, :pump_station, organization: division, contact_point: nil, pump_station: pump_station, name: "M-Pump") }
  let!(:pump_reading) { create(:meter_reading, meter: pump_meter, monthly_period: period, reading_start: 0, reading_end: 1000, consumption: 1000) }
  let!(:pump_assignment) { create(:pump_station_assignment, pump_station: pump_station, organization: organization) }

  # Config split per nghiệp vụ: Division row carries savings_rate +
  # division_public_rate (admin_level1), Unit row carries unit_public_rate +
  # other_deduction (admin_unit). Supply comes from MainMeterReading (1800)
  # → loss = 1800 − 0 − (704 CP + 1000 pump) = 96 (same target value as before).
  let!(:division_config) do
    create(:unit_config,
           organization: division,
           monthly_period: period,
           savings_rate: savings_rate,
           division_public_rate: div_public_rate,
           unit_public_rate: nil)
  end
  let!(:unit_config) do
    create(:unit_config,
           organization: organization,
           monthly_period: period,
           savings_rate: nil,
           division_public_rate: nil,
           unit_public_rate: unit_public_rate,
           other_deduction_type: :fixed_kw,
           other_deduction_value: bd("0"))
  end

  # -----------------------------------------------------------------------
  # Expected values — computed in BigDecimal following nghiệp vụ v5.
  # -----------------------------------------------------------------------
  # TMP Truong:   rank1=1 → 115 kW; pump_std = 1 × 9.45 = 9.45; total_std = 124.45
  # TB Q.Luc:     rank2=1, rank4=1 → 38 + 11 = 49 kW; pump_std = 2 × 9.45 = 18.90; total_std = 67.90
  # Ban Tac Huan: rank2=2 → 76 kW; pump_std = 2 × 9.45 = 18.90; total_std = 94.90
  # Total personnel org = 1 + 2 + 2 = 5
  # Loss-pool B = Σ CP meters (99+105+500=704) + pump (1000) = 1704 (zone-wide)
  # total_zone_loss = supply 1800 − no_loss 0 − B 1704 = 96
  # pump_loss_share = 96 × 1000/1704
  # pump_pool = 1000 + pump_loss_share
  let(:total_meter_consumption) { bd("1704") }
  let(:total_org_people)        { bd("5") }
  let(:total_zone_loss)         { bd("96") }
  let(:pump_consumption)        { bd("1000") }
  let(:pump_loss_share)         { total_zone_loss * pump_consumption / total_meter_consumption }
  let(:pump_pool)               { pump_consumption + pump_loss_share }

  def expected_for(rank_total_kw:, personnel_count:, meter_usage:)
    rank_total = bd(rank_total_kw)
    people     = bd(personnel_count)
    meter      = bd(meter_usage)

    water_pump_standard = people * water_pump_rate
    total_standard      = rank_total + water_pump_standard

    savings       = total_standard * savings_rate
    # Loss allocated by zone-wide meter-kW ratio (PR2 zone-loss rule).
    # Test fixture: CP meters only → cp_meter_consumption = meter_usage.
    loss          = total_zone_loss * meter / total_meter_consumption
    div_public    = total_standard * div_public_rate
    unit_public   = total_standard * unit_public_rate
    other         = bd("0")
    total_deduct  = savings + loss + div_public + unit_public + other
    remaining_std = total_standard - total_deduct

    # Pump pool absorbs its own share of zone loss before personnel-ratio split.
    pump_actual = pump_pool * people / total_org_people
    total_usage = meter + pump_actual

    over_under   = total_usage - remaining_std
    total_amount = over_under * unit_price

    {
      total_personnel:               personnel_count,
      water_pump_standard_kw:        water_pump_standard,
      total_standard_kw:             total_standard,
      savings_deduction_kw:          savings,
      loss_deduction_kw:             loss,
      division_public_deduction_kw:  div_public,
      unit_public_deduction_kw:      unit_public,
      other_deduction_kw:            other,
      total_deduction_kw:            total_deduct,
      remaining_standard_kw:         remaining_std,
      meter_usage_kw:                meter,
      water_pump_actual_kw:          pump_actual,
      total_usage_kw:                total_usage,
      over_under_kw:                 over_under,
      unit_price:                    unit_price,
      total_amount:                  total_amount
    }
  end

  let(:expected_truong)    { expected_for(rank_total_kw: 115, personnel_count: 1, meter_usage: 99) }
  let(:expected_qluc)      { expected_for(rank_total_kw: 49,  personnel_count: 2, meter_usage: 105) }
  let(:expected_tac_huan)  { expected_for(rank_total_kw: 76,  personnel_count: 2, meter_usage: 500) }

  # -----------------------------------------------------------------------
  # Subject
  # -----------------------------------------------------------------------
  subject(:engine) { described_class.new(organization: organization, monthly_period: period) }

  describe "#compute (full-precision BigDecimal)" do
    let(:results) { engine.compute }

    def result_for(cp) = results.find { |r| r[:contact_point_id] == cp.id }

    describe "F08 — Tiêu chuẩn" do
      it "rank1 kW for TMP Truong = 1 × 115" do
        expect(result_for(cp_truong)[:rank1_kw]).to eq(bd("115"))
      end

      it "rank2 kW for Ban Tac Huan = 2 × 38" do
        expect(result_for(cp_tac_huan)[:rank2_kw]).to eq(bd("76"))
      end

      it "water pump standard uses 9.45 kW/person (v5, NOT Excel 6.3)" do
        expect(result_for(cp_truong)[:water_pump_standard_kw]).to eq(expected_truong[:water_pump_standard_kw])
        expect(result_for(cp_qluc)[:water_pump_standard_kw]).to eq(expected_qluc[:water_pump_standard_kw])
        expect(result_for(cp_tac_huan)[:water_pump_standard_kw]).to eq(expected_tac_huan[:water_pump_standard_kw])
      end

      it "total_standard_kw = rank total + water pump standard" do
        expect(result_for(cp_truong)[:total_standard_kw]).to eq(expected_truong[:total_standard_kw])
        expect(result_for(cp_qluc)[:total_standard_kw]).to eq(expected_qluc[:total_standard_kw])
        expect(result_for(cp_tac_huan)[:total_standard_kw]).to eq(expected_tac_huan[:total_standard_kw])
      end
    end

    describe "F08 — Số phải trừ" do
      it "savings = total_standard × 5%" do
        expect(result_for(cp_truong)[:savings_deduction_kw]).to eq(expected_truong[:savings_deduction_kw])
        expect(result_for(cp_tac_huan)[:savings_deduction_kw]).to eq(expected_tac_huan[:savings_deduction_kw])
      end

      it "loss = total_unit_loss × (cp_meter_consumption / total_meter_consumption) — placed inside deductions" do
        expect(result_for(cp_truong)[:loss_deduction_kw]).to eq(expected_truong[:loss_deduction_kw])
        expect(result_for(cp_qluc)[:loss_deduction_kw]).to eq(expected_qluc[:loss_deduction_kw])
        expect(result_for(cp_tac_huan)[:loss_deduction_kw]).to eq(expected_tac_huan[:loss_deduction_kw])
      end

      it "CP loss + pump_loss_share sums to total_zone_loss" do
        cp_loss     = results.sum { |r| r[:loss_deduction_kw] }
        pump_actual = results.sum { |r| r[:water_pump_actual_kw] }
        # pump_pool = consumption + share → share = pump_actual_total − consumption.
        # (All pump consumption flows to this org's CPs since the single pump
        # assignment in the fixture targets this org.)
        # Tolerance to absorb BigDecimal precision drift across multiple divisions.
        expect(cp_loss + (pump_actual - pump_consumption)).to be_within(bd("0.0001")).of(total_zone_loss)
      end

      it "division public = total_standard × 10%" do
        expect(result_for(cp_truong)[:division_public_deduction_kw]).to eq(expected_truong[:division_public_deduction_kw])
        expect(result_for(cp_tac_huan)[:division_public_deduction_kw]).to eq(expected_tac_huan[:division_public_deduction_kw])
      end

      it "total_deduction_kw = savings + loss + division public + unit public + other" do
        expect(result_for(cp_truong)[:total_deduction_kw]).to eq(expected_truong[:total_deduction_kw])
        expect(result_for(cp_tac_huan)[:total_deduction_kw]).to eq(expected_tac_huan[:total_deduction_kw])
      end

      it "remaining_standard_kw = total_standard − total_deduction" do
        expect(result_for(cp_truong)[:remaining_standard_kw]).to eq(expected_truong[:remaining_standard_kw])
        expect(result_for(cp_qluc)[:remaining_standard_kw]).to eq(expected_qluc[:remaining_standard_kw])
        expect(result_for(cp_tac_huan)[:remaining_standard_kw]).to eq(expected_tac_huan[:remaining_standard_kw])
      end
    end

    describe "F09 — Sử dụng và so sánh" do
      it "meter_usage_kw excludes loss (v5: loss is NOT added to usage)" do
        expect(result_for(cp_truong)[:meter_usage_kw]).to eq(bd("99"))
        expect(result_for(cp_qluc)[:meter_usage_kw]).to eq(bd("105"))
        expect(result_for(cp_tac_huan)[:meter_usage_kw]).to eq(bd("500"))
      end

      it "water_pump_actual_kw is allocated from pump stations by personnel ratio (F10)" do
        expect(result_for(cp_truong)[:water_pump_actual_kw]).to eq(expected_truong[:water_pump_actual_kw])
        expect(result_for(cp_qluc)[:water_pump_actual_kw]).to eq(expected_qluc[:water_pump_actual_kw])
        expect(result_for(cp_tac_huan)[:water_pump_actual_kw]).to eq(expected_tac_huan[:water_pump_actual_kw])
      end

      it "total_usage_kw = meter usage + water pump actual" do
        expect(result_for(cp_truong)[:total_usage_kw]).to eq(expected_truong[:total_usage_kw])
        expect(result_for(cp_tac_huan)[:total_usage_kw]).to eq(expected_tac_huan[:total_usage_kw])
      end

      it "over_under_kw = total_usage − remaining_standard (positive = thâm, negative = tiết kiệm)" do
        expect(result_for(cp_truong)[:over_under_kw]).to eq(expected_truong[:over_under_kw])
        expect(result_for(cp_qluc)[:over_under_kw]).to eq(expected_qluc[:over_under_kw])
        expect(result_for(cp_tac_huan)[:over_under_kw]).to eq(expected_tac_huan[:over_under_kw])
      end

      it "total_amount = over_under × unit_price" do
        expect(result_for(cp_truong)[:total_amount]).to eq(expected_truong[:total_amount])
        expect(result_for(cp_tac_huan)[:total_amount]).to eq(expected_tac_huan[:total_amount])
      end

      it "unit_price is snapshot from monthly_period" do
        expect(result_for(cp_truong)[:unit_price]).to eq(unit_price)
      end
    end

    describe "determinism & precision" do
      it "returns BigDecimal for all numeric fields" do
        numeric_fields = %i[
          rank1_kw rank2_kw rank3_kw rank4_kw rank5_kw rank6_kw rank7_kw
          water_pump_standard_kw total_standard_kw
          savings_deduction_kw loss_deduction_kw
          division_public_deduction_kw unit_public_deduction_kw
          other_deduction_kw total_deduction_kw remaining_standard_kw
          meter_usage_kw water_pump_actual_kw total_usage_kw
          over_under_kw unit_price total_amount
        ]
        results.each do |row|
          numeric_fields.each do |f|
            expect(row[f]).to be_a(BigDecimal), "expected #{f} to be BigDecimal, got #{row[f].class}"
          end
        end
      end

      it "does NOT round intermediate calculations (e.g. loss allocation has many decimals)" do
        # 96 × 105 / 1704 is irrational in decimal — many digits.
        raw = result_for(cp_qluc)[:loss_deduction_kw]
        expected_raw = bd("96") * bd("105") / bd("1704")
        expect(raw).to eq(expected_raw)
      end
    end
  end

  describe "#call (persists to monthly_calculations)" do
    it "creates one MonthlyCalculation per contact point" do
      expect { engine.call }.to change(MonthlyCalculation, :count).by(3)
    end

    it "stores computed values rounded by decimal(12,2) column scale" do
      engine.call
      calc = MonthlyCalculation.find_by!(contact_point: cp_truong, monthly_period: period)

      # Persisted columns have scale=2; compare expected rounded to 2 decimals.
      expect(calc.rank1_kw).to eq(bd("115"))
      expect(calc.water_pump_standard_kw).to eq(expected_truong[:water_pump_standard_kw].round(2))
      expect(calc.total_standard_kw).to eq(expected_truong[:total_standard_kw].round(2))
      expect(calc.savings_deduction_kw).to eq(expected_truong[:savings_deduction_kw].round(2))
      expect(calc.loss_deduction_kw).to eq(expected_truong[:loss_deduction_kw].round(2))
      expect(calc.division_public_deduction_kw).to eq(expected_truong[:division_public_deduction_kw].round(2))
      expect(calc.remaining_standard_kw).to eq(expected_truong[:remaining_standard_kw].round(2))
      expect(calc.meter_usage_kw).to eq(bd("99"))
      expect(calc.water_pump_actual_kw).to eq(expected_truong[:water_pump_actual_kw].round(2))
      expect(calc.total_usage_kw).to eq(expected_truong[:total_usage_kw].round(2))
      expect(calc.over_under_kw).to eq(expected_truong[:over_under_kw].round(2))
      expect(calc.unit_price).to eq(unit_price)
      expect(calc.total_amount).to eq(expected_truong[:total_amount].round(2))
      expect(calc.total_personnel).to eq(1)
    end

    it "updates existing MonthlyCalculation rows when called twice (upsert)" do
      engine.call
      expect { engine.call }.not_to change(MonthlyCalculation, :count)
    end

    it "updates values if personnel changes between calls (fresh engine instance)" do
      engine.call
      p_truong.update!(rank1_count: 2)
      described_class.new(organization: organization, monthly_period: period).call

      calc = MonthlyCalculation.find_by!(contact_point: cp_truong, monthly_period: period)
      expect(calc.rank1_kw).to eq(bd("230"))   # 2 × 115
      expect(calc.total_personnel).to eq(2)
    end

    it "runs inside a transaction (rolls back on failure)" do
      allow_any_instance_of(MonthlyCalculation).to receive(:save!).and_wrap_original do |m, *args|
        raise ActiveRecord::RecordInvalid.new(m.receiver) if m.receiver.contact_point_id == cp_tac_huan.id

        m.call(*args)
      end

      expect { engine.call }.to raise_error(ActiveRecord::RecordInvalid)
      expect(MonthlyCalculation.where(monthly_period: period).count).to eq(0)
    end
  end

  describe "edge cases" do
    context "contact point with no personnel record" do
      let!(:cp_empty) { create(:contact_point, organization: organization, name: "Empty CP", position: 4) }

      it "treats all rank counts as zero and still computes" do
        results = engine.compute
        empty = results.find { |r| r[:contact_point_id] == cp_empty.id }
        expect(empty[:total_personnel]).to eq(0)
        expect(empty[:total_standard_kw]).to eq(bd("0"))
        expect(empty[:water_pump_standard_kw]).to eq(bd("0"))
        expect(empty[:loss_deduction_kw]).to eq(bd("0"))     # no meter readings → no allocation
        expect(empty[:water_pump_actual_kw]).to eq(bd("0"))  # no people → no allocation
      end
    end

    context "contact point with no meter readings" do
      let!(:cp_no_meter) { create(:contact_point, organization: organization, name: "No Meter CP", position: 5) }
      let!(:p_no_meter)  { create(:personnel, contact_point: cp_no_meter, monthly_period: period, rank1_count: 1, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

      it "uses 0 for meter_usage_kw and 0 loss (no meter → no loss allocation)" do
        results = engine.compute
        row = results.find { |r| r[:contact_point_id] == cp_no_meter.id }
        expect(row[:meter_usage_kw]).to eq(bd("0"))
        expect(row[:loss_deduction_kw]).to eq(bd("0"))
      end
    end

    context "zone with no supply (no MainMeterReading)" do
      before { main_meter_reading.destroy! }

      it "treats total_zone_loss as zero (loss_deduction = 0 for all)" do
        results = engine.compute
        results.each do |row|
          expect(row[:loss_deduction_kw]).to eq(bd("0"))
        end
      end
    end

    context "with no UnitConfig records at all (neither Division nor Unit)" do
      before do
        unit_config.destroy!
        division_config.destroy!
      end

      it "treats all rates as zero (no savings/public/other deduction)" do
        results = described_class.new(organization: organization, monthly_period: period).compute
        row = results.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(row[:savings_deduction_kw]).to eq(bd("0"))
        expect(row[:division_public_deduction_kw]).to eq(bd("0"))
        expect(row[:unit_public_deduction_kw]).to eq(bd("0"))
        expect(row[:other_deduction_kw]).to eq(bd("0"))
        # loss is supply-derived (still has MainMeterReading 1800) → non-zero.
      end
    end

    context "contact point with 'other' deduction — fixed_kw" do
      before do
        create(:contact_point_other_deduction, contact_point: cp_truong, monthly_period: period,
               other_type: :fixed_kw, other_value: bd("4"))
      end

      it "adds the fixed value to other_deduction_kw" do
        row = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(row[:other_deduction_kw]).to eq(bd("4"))
      end
    end

    context "contact point with 'other' deduction — factor_per_person" do
      before do
        create(:contact_point_other_deduction, contact_point: cp_qluc, monthly_period: period,
               other_type: :factor_per_person, other_value: bd("2"))
      end

      it "multiplies factor by personnel count" do
        row = engine.compute.find { |r| r[:contact_point_id] == cp_qluc.id }
        expect(row[:other_deduction_kw]).to eq(bd("4")) # 2 × 2 people
      end
    end

    context "pump station not assigned to this organization" do
      before { pump_assignment.destroy! }

      it "contributes 0 to water_pump_actual_kw" do
        row = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(row[:water_pump_actual_kw]).to eq(bd("0"))
      end
    end

    # Nghiệp vụ XAC_NHAN_NGHIEP_VU v5 mục 11 câu 1 (Zalo 21/04/2026):
    # Một số công tơ đặt tại trạm biến áp không đi qua đường dây nội bộ,
    # KHÔNG chịu tổn hao đường dây. kW công tơ no_loss phải bị trừ khỏi
    # supply TRƯỚC khi tính tổn hao, đồng thời không tham gia tử số/mẫu số
    # phân bổ tổn hao cho các CP khác.
    context "with no_loss meter (vị trí không tổn hao)" do
      # Tăng supply lên 1850: 1850 − 50 (no_loss) − 1704 (B) = 96
      # → tổng tổn hao zone vẫn = 96 (giữ nguyên expected_for cũ).
      let!(:cp_substation) { create(:contact_point, organization: organization, name: "Tram bien ap", position: 4) }
      let!(:meter_no_loss) { create(:meter, :no_loss, organization: organization, contact_point: cp_substation, name: "M-NoLoss") }
      let!(:reading_no_loss) do
        create(:meter_reading, meter: meter_no_loss, monthly_period: period,
                               reading_start: 0, reading_end: 50, consumption: 50)
      end
      before { main_meter_reading.update!(electricity_supply_kw: bd("1850")) }

      it "subtracts no_loss kW from supply before computing total_zone_loss" do
        # supply 1850 − no_loss 50 − B 1704 = 96. CP loss + pump_loss_share = 96.
        results = engine.compute
        cp_loss     = results.sum { |r| r[:loss_deduction_kw] }
        pump_actual = results.sum { |r| r[:water_pump_actual_kw] }
        expect(cp_loss + (pump_actual - pump_consumption)).to be_within(bd("0.0001")).of(bd("96"))
      end

      it "does not include no_loss meter in the loss-allocation denominator" do
        # mẫu số B = 99 + 105 + 500 + 1000 = 1704 (không có 50 của no_loss)
        loss = engine.compute.find { |r| r[:contact_point_id] == cp_qluc.id }[:loss_deduction_kw]
        expect(loss).to eq(bd("96") * bd("105") / bd("1704"))
      end

      it "assigns loss_deduction = 0 for a CP with only a no_loss meter" do
        row = engine.compute.find { |r| r[:contact_point_id] == cp_substation.id }
        expect(row[:loss_deduction_kw]).to eq(bd("0"))
      end

      it "includes no_loss consumption in meter_usage_kw (still billed)" do
        # no_loss only escapes the LOSS POOL; its consumption is real and must
        # be billed like any sinh-hoạt reading.
        row = engine.compute.find { |r| r[:contact_point_id] == cp_substation.id }
        expect(row[:meter_usage_kw]).to eq(bd("50"))
      end

      it "clamps total_zone_loss to 0 when supply < no_loss + B" do
        # supply 700 − no_loss 50 − B 1704 = -1054 → clamp về 0
        main_meter_reading.update!(electricity_supply_kw: bd("700"))
        described_class.new(organization: organization, monthly_period: period).compute.each do |row|
          expect(row[:loss_deduction_kw]).to eq(bd("0"))
        end
      end
    end
  end

  # Matches the "Bảng II" scenario from docs/BANG_22_COT_ANALYSIS.md §3.2:
  # a single pump station serves several units. Each served CP's share is
  # pump_pool × cp_people / (Σ people across ALL served orgs).
  describe "multi-unit pump allocation (real Excel 'Bảng II' case)" do
    let(:other_unit) { create(:organization, level: :unit, parent: division, main_meter: main_meter) }

    let!(:cp_other) { create(:contact_point, organization: other_unit, name: "CP Other") }
    let!(:p_other) do
      create(:personnel, contact_point: cp_other, monthly_period: period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 5,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end

    # Assign the SAME pump station to the other unit as well (so both share the pool).
    let!(:extra_assignment) { create(:pump_station_assignment, pump_station: pump_station, organization: other_unit) }

    it "distributes a shared pump station proportionally across all served orgs" do
      # Served total = 5 (organization) + 5 (other_unit) = 10
      # Pump pool = 1000 + 96×1000/1704 (both orgs in zone → pump_loss_share applies)
      # cp_truong (1) → pump_pool × 1 / 10
      results = engine.compute
      t    = results.find { |r| r[:contact_point_id] == cp_truong.id }
      q    = results.find { |r| r[:contact_point_id] == cp_qluc.id }
      h    = results.find { |r| r[:contact_point_id] == cp_tac_huan.id }

      expect(t[:water_pump_actual_kw]).to eq(pump_pool * bd("1") / bd("10"))
      expect(q[:water_pump_actual_kw]).to eq(pump_pool * bd("2") / bd("10"))
      expect(h[:water_pump_actual_kw]).to eq(pump_pool * bd("2") / bd("10"))

      # This org gets 5/10 of the pool (its 5 people out of 10 total served).
      sum_for_unit = results.sum { |r| r[:water_pump_actual_kw] }
      expect(sum_for_unit).to eq(pump_pool * bd("5") / bd("10"))
    end

    it "running the engine on the OTHER unit also gets its fair share" do
      other_engine = described_class.new(organization: other_unit, monthly_period: period)
      results = other_engine.compute
      other   = results.find { |r| r[:contact_point_id] == cp_other.id }
      # cp_other has 5 people; total served = 10
      expect(other[:water_pump_actual_kw]).to eq(pump_pool * bd("5") / bd("10"))
    end
  end

  # M6 nghiệp vụ 30/70 (XAC_NHAN_NGHIEP_VU v5.3.0 mục 6 + BANG_22_COT_ANALYSIS Bảng II).
  # Một số đầu mối hưởng tỷ lệ cố định trên consumption của trạm bơm; phần còn lại
  # chia cho các orgs khác theo quân số.
  describe "30/70 pump allocation (M6)" do
    # Pump allocation only — disable zone supply so pump_loss_share = 0 and the
    # pump pool equals raw consumption (matches the 30/70 examples in the docs).
    before { main_meter_reading.destroy! }

    let(:hq_unit)   { create(:organization, level: :unit, parent: division, name: "Chi huy F + nha khach") }
    let(:other_a)   { create(:organization, level: :unit, parent: division, name: "Other A") }

    let!(:cp_hq)    { create(:contact_point, organization: hq_unit, name: "CP HQ") }
    let!(:p_hq) do
      create(:personnel, contact_point: cp_hq, monthly_period: period,
             rank1_count: 0, rank2_count: 1, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end

    let!(:cp_other_a) { create(:contact_point, organization: other_a, name: "CP Other A") }
    let!(:p_other_a) do
      create(:personnel, contact_point: cp_other_a, monthly_period: period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 5,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end

    context "1 fixed (30%) + variable orgs sharing 70%" do
      let!(:hq_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: hq_unit,
               fixed_pump_percentage: bd("30"))
      end
      let!(:other_a_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: other_a)
      end

      it "fixed org receives consumption × 30/100, distributed to its CPs by personnel" do
        hq_engine = described_class.new(organization: hq_unit, monthly_period: period)
        row = hq_engine.compute.find { |r| r[:contact_point_id] == cp_hq.id }
        # 1000 × 30/100 = 300, single CP with 1 person → 300
        expect(row[:water_pump_actual_kw]).to eq(bd("300"))
      end

      it "variable orgs share 70% pool by personnel ratio (HQ excluded from denominator)" do
        # Variable pool = 1000 × 70/100 = 700
        # Variable orgs: organization (5 ppl) + other_a (5 ppl) = 10
        # Our org (organization) = 5/10 of 700 = 350
        # cp_truong (1) → 700 × 1 / 10 = 70
        # cp_qluc (2)   → 700 × 2 / 10 = 140
        # cp_tac_huan (2) → 700 × 2 / 10 = 140
        results = engine.compute
        t = results.find { |r| r[:contact_point_id] == cp_truong.id }
        q = results.find { |r| r[:contact_point_id] == cp_qluc.id }
        h = results.find { |r| r[:contact_point_id] == cp_tac_huan.id }
        expect(t[:water_pump_actual_kw]).to eq(bd("700") * bd("1") / bd("10"))
        expect(q[:water_pump_actual_kw]).to eq(bd("700") * bd("2") / bd("10"))
        expect(h[:water_pump_actual_kw]).to eq(bd("700") * bd("2") / bd("10"))
      end

      it "sum across all engine runs equals total pump consumption" do
        sum  = engine.compute.sum { |r| r[:water_pump_actual_kw] }                                              # 350
        sum += described_class.new(organization: other_a, monthly_period: period).compute
                              .sum { |r| r[:water_pump_actual_kw] }                                             # 350
        sum += described_class.new(organization: hq_unit, monthly_period: period).compute
                              .sum { |r| r[:water_pump_actual_kw] }                                             # 300
        expect(sum).to eq(bd("1000"))
      end
    end

    # Bảng II scenario: 1 fixed HQ (30%) + 5 variable orgs sharing 70% by personnel.
    # Personnel mix matches the Feb 2026 historical case (251+149+109+18+30=557).
    # Pump consumption 6152 = customer's typical zone usage; loss is disabled at
    # this describe-level so pump pool equals raw consumption.
    context "1 fixed (30%) + 5 variable orgs sharing 70%, total personnel 557" do
      let(:total) { bd("6152") }

      let(:org_co_quan)     { create(:organization, level: :unit, parent: division, name: "Co quan SDB") }
      let(:org_td18)        { create(:organization, level: :unit, parent: division, name: "Tieu doan 18 (real)") }
      let(:org_dd2023)      { create(:organization, level: :unit, parent: division, name: "Dai doi 20-23") }
      let(:org_che_bien)    { create(:organization, level: :unit, parent: division, name: "Tram che bien") }
      let(:org_tho_xay)     { create(:organization, level: :unit, parent: division, name: "Tho xay") }

      # CPs với personnel y như Excel: 251, 149, 109, 18, 30 (tổng 557)
      let!(:cp_co_quan) do
        cp = create(:contact_point, organization: org_co_quan, name: "Co quan SDB CP")
        create(:personnel, contact_point: cp, monthly_period: period,
               rank4_count: 251, rank1_count: 0, rank2_count: 0, rank3_count: 0,
               rank5_count: 0, rank6_count: 0, rank7_count: 0)
        cp
      end
      let!(:cp_td18) do
        cp = create(:contact_point, organization: org_td18, name: "TD18 CP")
        create(:personnel, contact_point: cp, monthly_period: period,
               rank4_count: 149, rank1_count: 0, rank2_count: 0, rank3_count: 0,
               rank5_count: 0, rank6_count: 0, rank7_count: 0)
        cp
      end
      let!(:cp_dd2023) do
        cp = create(:contact_point, organization: org_dd2023, name: "DD2023 CP")
        create(:personnel, contact_point: cp, monthly_period: period,
               rank4_count: 109, rank1_count: 0, rank2_count: 0, rank3_count: 0,
               rank5_count: 0, rank6_count: 0, rank7_count: 0)
        cp
      end
      let!(:cp_che_bien) do
        cp = create(:contact_point, organization: org_che_bien, name: "Che bien CP")
        create(:personnel, contact_point: cp, monthly_period: period,
               rank4_count: 18, rank1_count: 0, rank2_count: 0, rank3_count: 0,
               rank5_count: 0, rank6_count: 0, rank7_count: 0)
        cp
      end
      let!(:cp_tho_xay) do
        cp = create(:contact_point, organization: org_tho_xay, name: "Tho xay CP")
        create(:personnel, contact_point: cp, monthly_period: period,
               rank4_count: 30, rank1_count: 0, rank2_count: 0, rank3_count: 0,
               rank5_count: 0, rank6_count: 0, rank7_count: 0)
        cp
      end

      let(:variable_total) { bd("557") }

      before do
        # Override pump consumption to the real Excel total
        pump_reading.update!(reading_end: total, consumption: total)
        # 1 fixed assignment for HQ, 5 variable assignments
        create(:pump_station_assignment, pump_station: pump_station, organization: hq_unit,
               fixed_pump_percentage: bd("30"))
        create(:pump_station_assignment, pump_station: pump_station, organization: org_co_quan)
        create(:pump_station_assignment, pump_station: pump_station, organization: org_td18)
        create(:pump_station_assignment, pump_station: pump_station, organization: org_dd2023)
        create(:pump_station_assignment, pump_station: pump_station, organization: org_che_bien)
        create(:pump_station_assignment, pump_station: pump_station, organization: org_tho_xay)
        # The default fixture's pump_assignment for `organization` would also be a
        # variable claim. Remove it so the math matches the Excel — only Bảng II
        # orgs share the pool.
        pump_assignment.destroy!
      end

      it "HQ org receives 6152 × 30/100" do
        hq_engine = described_class.new(organization: hq_unit, monthly_period: period)
        row = hq_engine.compute.find { |r| r[:contact_point_id] == cp_hq.id }
        expect(row[:water_pump_actual_kw]).to eq(total * bd("30") / bd("100"))
      end

      it "Cơ quan SĐB (251 ng) receives (6152 × 70/100) × 251/557" do
        eng = described_class.new(organization: org_co_quan, monthly_period: period)
        row = eng.compute.find { |r| r[:contact_point_id] == cp_co_quan.id }
        pool = total * bd("70") / bd("100")
        expect(row[:water_pump_actual_kw]).to eq(pool * bd("251") / variable_total)
      end

      it "Tiểu đoàn 18 (149 ng) receives (6152 × 70/100) × 149/557" do
        eng = described_class.new(organization: org_td18, monthly_period: period)
        row = eng.compute.find { |r| r[:contact_point_id] == cp_td18.id }
        pool = total * bd("70") / bd("100")
        expect(row[:water_pump_actual_kw]).to eq(pool * bd("149") / variable_total)
      end

      it "Đại đội 20,23 (109 ng) receives (6152 × 70/100) × 109/557" do
        eng = described_class.new(organization: org_dd2023, monthly_period: period)
        row = eng.compute.find { |r| r[:contact_point_id] == cp_dd2023.id }
        pool = total * bd("70") / bd("100")
        expect(row[:water_pump_actual_kw]).to eq(pool * bd("109") / variable_total)
      end

      it "Trạm chế biến (18 ng) receives (6152 × 70/100) × 18/557" do
        eng = described_class.new(organization: org_che_bien, monthly_period: period)
        row = eng.compute.find { |r| r[:contact_point_id] == cp_che_bien.id }
        pool = total * bd("70") / bd("100")
        expect(row[:water_pump_actual_kw]).to eq(pool * bd("18") / variable_total)
      end

      it "Thợ xây (30 ng) receives (6152 × 70/100) × 30/557" do
        eng = described_class.new(organization: org_tho_xay, monthly_period: period)
        row = eng.compute.find { |r| r[:contact_point_id] == cp_tho_xay.id }
        pool = total * bd("70") / bd("100")
        expect(row[:water_pump_actual_kw]).to eq(pool * bd("30") / variable_total)
      end

      it "sum across all 6 engine runs equals total consumption (no kW lost)" do
        sum = bd("0")
        [ hq_unit, org_co_quan, org_td18, org_dd2023, org_che_bien, org_tho_xay ].each do |org|
          eng = described_class.new(organization: org, monthly_period: period)
          sum += eng.compute.sum { |r| r[:water_pump_actual_kw] }
        end
        # Tolerance vì chia 4494.14 cho 557 (irrational); BigDecimal default precision tích luỹ
        # error rất nhỏ qua 5 lần chia. Đảm bảo không có kW nào bị mất ở mức nghiệp vụ.
        expect(sum).to be_within(bd("0.0001")).of(total)
      end
    end

    context "edge: sum_fixed_pct >= 100" do
      let!(:hq_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: hq_unit,
               fixed_pump_percentage: bd("60"))
      end
      let!(:other_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: other_a,
               fixed_pump_percentage: bd("60"))
      end

      it "clamps fixed total to 100 → variable orgs receive 0" do
        results = engine.compute
        truong = results.find { |r| r[:contact_point_id] == cp_truong.id }
        # Our `organization` is variable but pool = 0, so its CPs all get 0
        expect(truong[:water_pump_actual_kw]).to eq(bd("0"))
      end
    end

    context "edge: fixed org with 0 personnel" do
      let(:empty_hq) { create(:organization, level: :unit, parent: division, name: "Empty HQ") }
      let!(:cp_empty_hq) { create(:contact_point, organization: empty_hq, name: "CP Empty") }
      # No Personnel record → 0 people in the org
      let!(:empty_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: empty_hq,
               fixed_pump_percentage: bd("30"))
      end

      it "loses the fixed slice (CPs with 0 personnel are skipped)" do
        empty_engine = described_class.new(organization: empty_hq, monthly_period: period)
        row = empty_engine.compute.find { |r| r[:contact_point_id] == cp_empty_hq.id }
        expect(row[:water_pump_actual_kw]).to eq(bd("0"))
      end

      it "variable pool stays at 70% — does not absorb the lost slice" do
        # Our org (5 ppl) is the only variable org → it gets the entire 70%
        truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        # 1000 × 70/100 × 1/5 = 140
        expect(truong[:water_pump_actual_kw]).to eq(bd("700") * bd("1") / bd("5"))
      end
    end

    context "edge: variable org with 0 personnel" do
      let(:empty_unit) { create(:organization, level: :unit, parent: division, name: "Empty unit") }
      let!(:cp_empty) { create(:contact_point, organization: empty_unit, name: "CP Empty unit") }
      let!(:empty_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: empty_unit)
      end

      it "the empty org receives 0; existing org receives full pool" do
        # Variable orgs: organization (5 ppl) + empty_unit (0 ppl) = 5
        # Pool = 1000 (no fixed), our org gets 1000 × 5/5 = 1000 (its CPs by ratio)
        truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:water_pump_actual_kw]).to eq(bd("1000") * bd("1") / bd("5"))
      end
    end

    context "edge: fixed_pump_percentage = 0" do
      let!(:zero_assignment) do
        create(:pump_station_assignment, pump_station: pump_station, organization: hq_unit,
               fixed_pump_percentage: bd("0"))
      end

      it "treats 0 as fixed (HQ org receives 0 kW, NOT in variable pool)" do
        hq_engine = described_class.new(organization: hq_unit, monthly_period: period)
        row = hq_engine.compute.find { |r| r[:contact_point_id] == cp_hq.id }
        expect(row[:water_pump_actual_kw]).to eq(bd("0"))
      end

      it "variable pool = 100% (sum_fixed_pct = 0); our org receives full share" do
        # Our org is the only variable assignment (5 ppl)
        truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:water_pump_actual_kw]).to eq(bd("1000") * bd("1") / bd("5"))
      end
    end
  end

  # PumpStation→Meter is 1-many: a station may have several physical meters.
  # Engine sums consumption across all meters of the station for the period.
  describe "multiple meters per pump station" do
    let!(:second_pump_meter) do
      create(:meter, :pump_station, organization: division,
                                    contact_point: nil, pump_station: pump_station,
                                    name: "M-Pump-2")
    end
    let!(:second_pump_reading) do
      create(:meter_reading, meter: second_pump_meter, monthly_period: period,
                             reading_start: 0, reading_end: 500, consumption: 500)
    end

    it "sums consumption across all meters (1000 + 500 = 1500), allocated by personnel" do
      # All 5 personnel in our organization → full pool (no fixed assignments).
      # cp_truong has 1/5 of personnel.
      truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
      expect(truong[:water_pump_actual_kw]).to eq(bd("1500") * bd("1") / bd("5"))
    end
  end

  # ---------------------------------------------------------------------------
  # Regression: engine reads savings_rate + division_public_rate from the
  # Division-level UnitConfig (admin_level1's row), not the Unit-level row.
  # The UI for /unit_configs writes these two rates to the division's record.
  # ---------------------------------------------------------------------------
  describe "config lookup across Division and Unit rows" do
    let(:total_standard_truong) { bd("115") + bd("9.45") } # rank1=1 → 115 + 1×9.45

    context "when both rates live on the Division row" do
      it "applies savings_rate from the Division UnitConfig" do
        truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:savings_deduction_kw]).to eq(total_standard_truong * bd("0.05"))
      end

      it "applies division_public_rate from the Division UnitConfig" do
        truong = engine.compute.find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:division_public_deduction_kw]).to eq(total_standard_truong * bd("0.10"))
      end
    end

    context "when only the Unit row is present (Division row missing)" do
      before { division_config.destroy! }

      it "yields zero savings_deduction" do
        truong = described_class.new(organization: organization, monthly_period: period).compute
                                .find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:savings_deduction_kw]).to eq(bd("0"))
      end

      it "yields zero division_public_deduction" do
        truong = described_class.new(organization: organization, monthly_period: period).compute
                                .find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:division_public_deduction_kw]).to eq(bd("0"))
      end
    end

    context "when rates are misplaced on the Unit row (legacy data)" do
      before do
        division_config.update!(savings_rate: nil, division_public_rate: nil)
        unit_config.update!(savings_rate: bd("0.05"), division_public_rate: bd("0.10"))
      end

      it "ignores them — engine looks ONLY at the Division row" do
        truong = described_class.new(organization: organization, monthly_period: period).compute
                                .find { |r| r[:contact_point_id] == cp_truong.id }
        expect(truong[:savings_deduction_kw]).to eq(bd("0"))
        expect(truong[:division_public_deduction_kw]).to eq(bd("0"))
      end
    end

    it "still reads unit_public_rate from the Unit's own UnitConfig" do
      unit_config.update!(unit_public_rate: bd("0.07"))
      truong = described_class.new(organization: organization, monthly_period: period).compute
                              .find { |r| r[:contact_point_id] == cp_truong.id }
      expect(truong[:unit_public_deduction_kw]).to eq(total_standard_truong * bd("0.07"))
    end
  end
end
