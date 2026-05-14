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
RSpec.describe CalculationOrchestrator do
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
  let_it_be(:division)    { create(:organization, :division) }
  let_it_be(:main_meter)  { create(:main_meter, name: "Zone fixture") }
  let_it_be(:organization) { create(:organization, level: :unit, parent: division, zone: main_meter.zone) }
  let_it_be(:period)      { create(:monthly_period, year: 2026, month: 2, unit_price: BigDecimal("2336.4")) }
  # main_meter_reading stays let! — destroyed/updated by several contexts.
  let!(:main_meter_reading) do
    create(:main_meter_reading,
           main_meter: main_meter, monthly_period: period,
           electricity_supply_kw: bd("1800"))
  end

  let_it_be(:rank_quota1) { create(:rank_quota, rank_group: 1, rank_name: "3*/4*",   quota_kw: bd("115")) }
  let_it_be(:rank_quota2) { create(:rank_quota, rank_group: 2, rank_name: "1*/2*",   quota_kw: bd("38")) }
  let_it_be(:rank_quota3) { create(:rank_quota, rank_group: 3, rank_name: "Cap uy",  quota_kw: bd("28")) }
  let_it_be(:rank_quota4) { create(:rank_quota, rank_group: 4, rank_name: "HSQ-CS",  quota_kw: bd("11")) }

  let_it_be(:cp_truong)    { create(:contact_point, organization: organization, name: "TMP Truong",   position: 1) }
  let_it_be(:cp_qluc)      { create(:contact_point, organization: organization, name: "TB Q.Luc",     position: 2) }
  let_it_be(:cp_tac_huan)  { create(:contact_point, organization: organization, name: "Ban Tac Huan", position: 3) }

  # Personnel — Excel columns E/F/G/H mapped to rank 1..4
  # p_truong stays let! — updated by the #call persistence example.
  let!(:p_truong)        { create(:personnel, contact_point: cp_truong,   monthly_period: period, rank1_count: 1, rank2_count: 0, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }
  let_it_be(:p_qluc)     { create(:personnel, contact_point: cp_qluc,     monthly_period: period, rank1_count: 0, rank2_count: 1, rank3_count: 0, rank4_count: 1, rank5_count: 0, rank6_count: 0, rank7_count: 0) }
  let_it_be(:p_tac_huan) { create(:personnel, contact_point: cp_tac_huan, monthly_period: period, rank1_count: 0, rank2_count: 2, rank3_count: 0, rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) }

  # Meter readings (normal) — one per contact point. Arbitrary but realistic.
  let_it_be(:meter_truong)   { create(:meter, :normal, organization: organization, contact_point: cp_truong,   name: "M-Truong") }
  let_it_be(:meter_qluc)     { create(:meter, :normal, organization: organization, contact_point: cp_qluc,     name: "M-QLuc") }
  let_it_be(:meter_tac_huan) { create(:meter, :normal, organization: organization, contact_point: cp_tac_huan, name: "M-TacHuan") }

  let_it_be(:reading_truong)   { create(:meter_reading, meter: meter_truong,   monthly_period: period, reading_start: 0, reading_end: 99,  consumption: 99) }
  let_it_be(:reading_qluc)     { create(:meter_reading, meter: meter_qluc,     monthly_period: period, reading_start: 0, reading_end: 105, consumption: 105) }
  let_it_be(:reading_tac_huan) { create(:meter_reading, meter: meter_tac_huan, monthly_period: period, reading_start: 0, reading_end: 500, consumption: 500) }

  # Pump station — 1 trạm bơm phục vụ organization, tổng điện 1000 kW.
  let_it_be(:pump_station) { create(:pump_station, zone: main_meter.zone, name: "TB 1") }
  let_it_be(:pump_meter)   { create(:meter, :pump_station, organization: division, contact_point: nil, pump_station: pump_station, name: "M-Pump") }
  # pump_reading + pump_assignment stay let! — updated/destroyed by 557 + edge contexts.
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

  # -----------------------------------------------------------------------
  # Subject
  # -----------------------------------------------------------------------
  subject(:engine) { described_class.new(organization: organization, monthly_period: period) }

  describe "#compute (full-precision BigDecimal)" do
    let(:results) { engine.compute }

    def result_for(cp) = results.find { |r| r[:contact_point_id] == cp.id }

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

  end

  # Matches the "Bảng II" scenario from docs/BANG_22_COT_ANALYSIS.md §3.2:
  # a single pump station serves several units. Each served CP's share is
  # pump_pool × cp_people / (Σ people across ALL served orgs).
  describe "multi-unit pump allocation (real Excel 'Bảng II' case)" do
    let(:other_unit) { create(:organization, level: :unit, parent: division, zone: main_meter.zone) }

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

    let(:hq_unit)   { create(:organization, level: :unit, parent: division, name: "Chi huy F + nha khach", zone: main_meter.zone) }

    let!(:cp_hq)    { create(:contact_point, organization: hq_unit, name: "CP HQ") }
    let!(:p_hq) do
      create(:personnel, contact_point: cp_hq, monthly_period: period,
             rank1_count: 0, rank2_count: 1, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end

    # Bảng II scenario: 1 fixed HQ (30%) + 5 variable orgs sharing 70% by personnel.
    # Personnel mix matches the Feb 2026 historical case (251+149+109+18+30=557).
    # Pump consumption 6152 = customer's typical zone usage; loss is disabled at
    # this describe-level so pump pool equals raw consumption.
    context "1 fixed (30%) + 5 variable orgs sharing 70%, total personnel 557" do
      let(:total) { bd("6152") }

      let(:org_co_quan)     { create(:organization, level: :unit, parent: division, name: "Co quan SDB", zone: main_meter.zone) }
      let(:org_td18)        { create(:organization, level: :unit, parent: division, name: "Tieu doan 18 (real)", zone: main_meter.zone) }
      let(:org_dd2023)      { create(:organization, level: :unit, parent: division, name: "Dai doi 20-23", zone: main_meter.zone) }
      let(:org_che_bien)    { create(:organization, level: :unit, parent: division, name: "Tram che bien", zone: main_meter.zone) }
      let(:org_tho_xay)     { create(:organization, level: :unit, parent: division, name: "Tho xay", zone: main_meter.zone) }

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

  # Verifies that CalculationOrchestrator wires per-CP pump kW correctly when the
  # pump phase is delegated to PumpAllocationCalculator. Each scenario sets
  # up two zone-mates (DVA + DVB) sharing one pump station, with one
  # ContactPoint fixed slot, two Organization variable slots, and a
  # WorkGroup variable slot (which counts toward the denominator but never
  # surfaces in MonthlyCalculation rows).
  #
  # Numbers (BigDecimal, no rounding):
  #   supply = 2000, no_loss = 100, B = 1680 → total_zone_loss = 220
  #   pump_loss_share(TB1) = 220 × 500 / 1680
  #   pump_pool            = 500 + pump_loss_share
  #
  #   A1 fixed 30%        = pool × 0.30
  #   Variable pool 70%   = pool × 0.70
  #     headcount DVA 6 + DVB 5 + WG 2 = 13
  describe "pump allocation wiring (through PumpAllocationCalculator)" do
    let(:zone_division) { create(:organization, :division) }
    let(:zone_mm)       { create(:main_meter, name: "Khu vuc A") }
    let(:dva)           { create(:organization, level: :unit, parent: zone_division, name: "DVA", zone: zone_mm.zone) }
    let(:dvb)           { create(:organization, level: :unit, parent: zone_division, name: "DVB", zone: zone_mm.zone) }
    let(:zone_period)   { create(:monthly_period, year: 2026, month: 4, unit_price: bd("2336.4")) }

    # rank_quotas 1..4 already declared at the top of this spec file; pump
    # allocation tests only check water_pump_actual_kw + total_usage_kw,
    # which don't depend on rank quotas.
    let!(:zone_supply_reading) do
      create(:main_meter_reading,
             main_meter: zone_mm, monthly_period: zone_period,
             electricity_supply_kw: bd("2000"))
    end
    let!(:zone_division_cfg) do
      create(:unit_config,
             organization: zone_division, monthly_period: zone_period,
             savings_rate: bd("0.05"), division_public_rate: bd("0.10"),
             unit_public_rate: nil)
    end

    let!(:zcp_a1) { create(:contact_point, organization: dva, name: "A1 Ban Chi huy", position: 1) }
    let!(:zcp_a2) { create(:contact_point, organization: dva, name: "A2 To xe",      position: 2) }
    let!(:zcp_a3) { create(:contact_point, organization: dva, name: "A3 Kho",        position: 3) }
    let!(:zcp_a4) { create(:contact_point, organization: dva, name: "A4 Den duong",  group_name: "public", position: 4) }
    let!(:zcp_b1) { create(:contact_point, organization: dvb, name: "B1 Dai doi 1",  position: 1) }

    let!(:zp_a1) do
      create(:personnel, contact_point: zcp_a1, monthly_period: zone_period,
             rank1_count: 1, rank2_count: 1, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end
    let!(:zp_a2) do
      create(:personnel, contact_point: zcp_a2, monthly_period: zone_period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 3)
    end
    let!(:zp_a3) do
      create(:personnel, contact_point: zcp_a3, monthly_period: zone_period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 1,
             rank5_count: 0, rank6_count: 0, rank7_count: 0)
    end
    let!(:zp_b1) do
      create(:personnel, contact_point: zcp_b1, monthly_period: zone_period,
             rank1_count: 0, rank2_count: 0, rank3_count: 0, rank4_count: 0,
             rank5_count: 0, rank6_count: 0, rank7_count: 5)
    end

    let!(:zm_a1) do
      m = create(:meter, :normal, organization: dva, contact_point: zcp_a1, name: "A1-CT1")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 800, consumption: 800)
      m
    end
    let!(:zm_a2_1) do
      m = create(:meter, :normal, organization: dva, contact_point: zcp_a2, name: "A2-CT1")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 50, consumption: 50)
      m
    end
    let!(:zm_a2_2) do
      m = create(:meter, :normal, organization: dva, contact_point: zcp_a2, name: "A2-CT2")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 30, consumption: 30)
      m
    end
    let!(:zm_a3) do
      m = create(:meter, :no_loss, organization: dva, contact_point: zcp_a3, name: "A3-CT1 no_loss")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 100, consumption: 100)
      m
    end
    let!(:zm_a4) do
      m = create(:meter, :public_meter, organization: dva, contact_point: zcp_a4, name: "A4-CT1 public")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 200, consumption: 200)
      m
    end
    let!(:zm_b1) do
      m = create(:meter, :normal, organization: dvb, contact_point: zcp_b1, name: "B1-CT1")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 100, consumption: 100)
      m
    end

    let!(:zone_pump_station) { create(:pump_station, zone: zone_mm.zone, name: "TB1") }
    let!(:zm_pump) do
      m = create(:meter, :pump_station, organization: zone_division, contact_point: nil,
                 pump_station: zone_pump_station, name: "TB1-CT1")
      create(:meter_reading, meter: m, monthly_period: zone_period, reading_start: 0, reading_end: 500, consumption: 500)
      m
    end

    let!(:zone_work_group) do
      create(:work_group, owner_organization: dva, name: "Tho xay",
             personnel_count: 2, position: 0)
    end

    let!(:zasg_a1)  { create(:pump_station_assignment, pump_station: zone_pump_station, assignable: zcp_a1, fixed_pump_percentage: 30) }
    let!(:zasg_dva) { create(:pump_station_assignment, pump_station: zone_pump_station, assignable: dva) }
    let!(:zasg_dvb) { create(:pump_station_assignment, pump_station: zone_pump_station, assignable: dvb) }
    let!(:zasg_wg)  { create(:pump_station_assignment, pump_station: zone_pump_station, assignable: zone_work_group) }

    let(:zone_tolerance) { bd("0.01") }
    let(:engine_dva)     { CalculationOrchestrator.new(organization: dva, monthly_period: zone_period) }
    let(:engine_dvb)     { CalculationOrchestrator.new(organization: dvb, monthly_period: zone_period) }

    let(:zone_pump_pool)    { bd("500") + (bd("220") * bd("500") / bd("1680")) }
    let(:zone_variable_pool) { zone_pump_pool * bd("0.70") }

    context "mixed CP fixed + Org variable + WorkGroup variable" do
      let(:results_dva) { engine_dva.compute }
      let(:results_dvb) { engine_dvb.compute }

      it "credits A1 with BOTH its CP-level 30% slot AND its slice of DVA's variable share" do
        a1_row = results_dva.find { |r| r[:contact_point_id] == zcp_a1.id }
        cp_fixed_share     = zone_pump_pool * bd("0.30")
        dva_variable_share = zone_variable_pool * bd("6") / bd("13")
        a1_from_dva        = dva_variable_share * bd("2") / bd("6")

        expect(a1_row[:water_pump_actual_kw]).to be_within(zone_tolerance)
          .of(cp_fixed_share + a1_from_dva)
        expect(a1_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(bd("230.540"))
      end

      it "splits DVA's variable share across A2/A3/A4 by personnel" do
        a2_row = results_dva.find { |r| r[:contact_point_id] == zcp_a2.id }
        a3_row = results_dva.find { |r| r[:contact_point_id] == zcp_a3.id }
        a4_row = results_dva.find { |r| r[:contact_point_id] == zcp_a4.id }

        dva_share = zone_variable_pool * bd("6") / bd("13")

        expect(a2_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(dva_share * bd("3") / bd("6"))
        expect(a3_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(dva_share * bd("1") / bd("6"))
        expect(a4_row[:water_pump_actual_kw]).to eq(bd("0"))
      end

      it "gives DVB its full 5/13 variable share (single CP B1)" do
        b1_row = results_dvb.find { |r| r[:contact_point_id] == zcp_b1.id }
        expect(b1_row[:water_pump_actual_kw])
          .to be_within(zone_tolerance).of(zone_variable_pool * bd("5") / bd("13"))
      end

      it "sets A1 total_usage = meter + pump" do
        a1_row = results_dva.find { |r| r[:contact_point_id] == zcp_a1.id }
        expect(a1_row[:total_usage_kw]).to be_within(zone_tolerance).of(bd("1030.540"))
      end

      it "does not surface WorkGroup share through MonthlyCalculation rows" do
        all_rows = engine_dva.compute + engine_dvb.compute
        cp_sum   = all_rows.sum { |r| r[:water_pump_actual_kw] }
        wg_share = zone_variable_pool * bd("2") / bd("13")
        expect(cp_sum).to be_within(bd("0.05")).of(zone_pump_pool - wg_share)
      end
    end

    # CPG1 = {A2, A3} gets a 20% fixed slot on TB1's pump pool. That share
    # is split across the group's member CPs by personnel ratio (A2:3, A3:1).
    # CPG stacking: A2/A3 still receive their slice of DVA's variable share.
    context "with ContactPointGroup assignment" do
      let!(:cpg1)        { create(:contact_point_group, organization: dva, name: "Nhóm A2-A3") }
      let!(:cpg1_mem_a2) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: zcp_a2) }
      let!(:cpg1_mem_a3) { create(:contact_point_group_membership, contact_point_group: cpg1, contact_point: zcp_a3) }
      let!(:zasg_cpg1) do
        create(:pump_station_assignment, pump_station: zone_pump_station,
               assignable: cpg1, fixed_pump_percentage: 20)
      end

      # sum_fixed_pct = 30 (A1) + 20 (CPG1) = 50 → variable_pct = 50
      let(:variable_pool_50) { zone_pump_pool * bd("0.50") }
      let(:cpg1_share)       { zone_pump_pool * bd("0.20") }

      it "phân bổ CPG1 fixed share xuống A2/A3 theo personnel (3:1)" do
        results = engine_dva.compute
        a2_row = results.find { |r| r[:contact_point_id] == zcp_a2.id }
        a3_row = results.find { |r| r[:contact_point_id] == zcp_a3.id }

        dva_var     = variable_pool_50 * bd("6") / bd("13")
        a2_expected = (cpg1_share * bd("3") / bd("4")) + (dva_var * bd("3") / bd("6"))
        a3_expected = (cpg1_share * bd("1") / bd("4")) + (dva_var * bd("1") / bd("6"))

        expect(a2_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(a2_expected)
        expect(a3_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(a3_expected)
      end

      it "không cộng CPG1 share vào A1 (A1 không là member)" do
        results = engine_dva.compute
        a1_row = results.find { |r| r[:contact_point_id] == zcp_a1.id }

        cp_fixed_share = zone_pump_pool * bd("0.30")
        dva_var        = variable_pool_50 * bd("6") / bd("13")
        a1_from_dva    = dva_var * bd("2") / bd("6")

        expect(a1_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(cp_fixed_share + a1_from_dva)
      end

      it "pump chỉ có ContactPointGroup assignment vẫn được engine tìm thấy" do
        # Xoá hết assignment khác — pump TB1 chỉ còn CPG1 (fixed 20%). Không
        # còn variable target → variable pool dissipates. CPG1 nhận 20% pool,
        # chia xuống A2 (3/4) và A3 (1/4).
        [ zasg_a1, zasg_dva, zasg_dvb, zasg_wg ].each(&:destroy)

        results = CalculationOrchestrator.new(organization: dva, monthly_period: zone_period).compute
        a2_row = results.find { |r| r[:contact_point_id] == zcp_a2.id }
        a3_row = results.find { |r| r[:contact_point_id] == zcp_a3.id }
        a1_row = results.find { |r| r[:contact_point_id] == zcp_a1.id }

        expect(a2_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(cpg1_share * bd("3") / bd("4"))
        expect(a3_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(cpg1_share * bd("1") / bd("4"))
        expect(a1_row[:water_pump_actual_kw]).to eq(bd("0"))
      end

      it "CPG thuộc org khác không bleed vào CP của engine hiện tại" do
        # Group thuộc DVB nhưng được assign vào TB1 → PAC zone-wide vẫn phân
        # bổ share, nhưng share đó chỉ rơi vào B1 (member của cpg_dvb), không
        # vào A2/A3 của DVA. Engine DVA không thấy share này.
        cpg_dvb = create(:contact_point_group, organization: dvb, name: "Nhóm DVB")
        create(:contact_point_group_membership, contact_point_group: cpg_dvb, contact_point: zcp_b1)
        create(:pump_station_assignment, pump_station: zone_pump_station,
               assignable: cpg_dvb, fixed_pump_percentage: 10)

        results = engine_dva.compute
        a2_row = results.find { |r| r[:contact_point_id] == zcp_a2.id }

        # Variable_pct = 100 - 30 - 20 - 10 = 40. DVA variable share = 40% × 6/13.
        variable_pool_40 = zone_pump_pool * bd("0.40")
        dva_var          = variable_pool_40 * bd("6") / bd("13")
        a2_expected      = (cpg1_share * bd("3") / bd("4")) + (dva_var * bd("3") / bd("6"))

        expect(a2_row[:water_pump_actual_kw]).to be_within(zone_tolerance).of(a2_expected)
      end
    end
  end
end
