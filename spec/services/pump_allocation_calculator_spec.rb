require "rails_helper"

RSpec.describe PumpAllocationCalculator do
  describe "#call — T02 (dữ liệu mẫu mục 1)" do
    let(:sample) { setup_zone_one_full_sample }
    let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }
    let(:result) {
      described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
    }

    it "total_d = 309,33 (raw 300 + tổn hao 9,33)" do
      expect(result.total_d).to eq_display("309.33")
    end

    it "Chỉ huy khu vực (20% cố định) = 61,87" do
      expect(result.contact_point_allocations[sample.contact_points[:chi_huy_khu_vuc].id]).to eq_display("61.87")
    end

    it "Ban Tác huấn (Đơn vị A → 5 người) = 52,65" do
      expect(result.contact_point_allocations[sample.contact_points[:ban_tac_huan].id]).to eq_display("52.65")
    end

    it "Văn thư (Đơn vị A → 2 người) = 21,06" do
      expect(result.contact_point_allocations[sample.contact_points[:van_thu].id]).to eq_display("21.06")
    end

    it "Kho vật tư (Đơn vị A → 3 người) = 31,59" do
      expect(result.contact_point_allocations[sample.contact_points[:kho_vat_tu].id]).to eq_display("31.59")
    end

    it "Đại đội 1 (Đơn vị B → 11 người, nhận toàn bộ phần B) = 115,83" do
      expect(result.contact_point_allocations[sample.contact_points[:dai_doi_1].id]).to eq_display("115.83")
    end

    it "Thợ xây (ngoài biên chế) nhận 26,33 — vẫn ở contact_point_allocations" do
      expect(result.contact_point_allocations[sample.contact_points[:tho_xay].id]).to eq_display("26.33")
    end

    it "tổng tất cả phân bổ = D = 309,33" do
      total = result.contact_point_allocations.values.sum(BigDecimal("0"))
      expect(total.round(2, BigDecimal::ROUND_HALF_UP)).to eq(BigDecimal("309.33"))
    end

    it "không có cảnh báo" do
      expect(result.warnings).to be_empty
    end
  end

  describe "edge cases" do
    context "không có công tơ bơm nước (hard delete để engine với .with_discarded vẫn không thấy)" do
      let(:sample) { setup_zone_one_full_sample }
      let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

      before do
        # v2.3.0: engine query với .with_discarded, nên discard không đủ.
        # Hard delete meter_readings + meter + contact_point để thật sự không còn pump meter.
        MeterReading.where(meter_id: sample.meters[:ct_bn1].id).delete_all
        PumpAllocation.where(contact_point_id: sample.contact_points[:tram_bom_1].id).delete_all
        Meter.with_discarded.where(id: sample.meters[:ct_bn1].id).delete_all
        ContactPoint.with_discarded.where(id: sample.contact_points[:tram_bom_1].id).delete_all
      end

      it "d = 0 + cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
        expect(result.total_d).to eq(0)
        expect(result.contact_point_allocations).to be_empty
        expect(result.warnings)
          .to include(I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter"))
      end
    end

    context "tổng fixed_percentage = 100% → coefficient bỏ qua" do
      let(:sample) { setup_zone_one_full_sample }
      let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

      before do
        sample.pump_allocations[:chi_huy_khu_vuc].update!(fixed_percentage: BigDecimal("100"))
      end

      it "Chỉ huy khu vực nhận 100% D, các đơn vị nhận 0" do
        result = described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
        expect(result.contact_point_allocations[sample.contact_points[:chi_huy_khu_vuc].id])
          .to eq_display("309.33")
        expect(result.contact_point_allocations[sample.contact_points[:ban_tac_huan].id] || 0).to eq(0)
      end
    end
  end

  # Khoá biên & các nhánh phân bổ hệ số (mutation #376). Mỗi test dựng một khu vực
  # tối thiểu với nguồn D = 100 (loss_results rỗng), rồi nhắm đúng một nhánh.
  describe "#call — biên & nhánh phân bổ hệ số (mutation #376)" do
    def empty_loss_results
      LossCalculator::Result.new(meter_losses: {}, contact_point_losses: {},
                                 total_loss: BigDecimal("0"), total_a: BigDecimal("0"),
                                 total_b: BigDecimal("0"), warnings: [])
    end

    # Mở kỳ + dựng nguồn D: đầu mối bơm nước + công tơ + chỉ số. loss_results rỗng nên
    # D = raw_pump_usage = pump_usage. Trả về [zone, period].
    def build_pump_zone(name:, pump_usage: BigDecimal("100"))
      zone = create(:zone, name: name)
      period = PeriodService.new.open_new_period(
        year: 2026, month: 1, unit_price: BigDecimal("2000")
      ).period
      pump_cp = create(:contact_point, :water_pump, name: "#{name} — bơm", zone: zone)
      pump_meter = create(:meter, name: "#{name}-BN", contact_point: pump_cp, no_loss: false)
      pump_meter.meter_readings.find_by!(period: period)
                .update!(reading_start: BigDecimal("0"), reading_end: pump_usage)
      [zone, period]
    end

    def call_pump(zone, period)
      described_class.new(zone: zone, period: period, loss_results: empty_loss_results).call
    end

    def rank_for(period)
      period.ranks.find_by!(position: 7) # Hạ sĩ quan, binh sĩ
    end

    def zero_personnel_warning
      I18n.t("services.pump_allocation_calculator.warnings.zero_personnel")
    end

    it "total_weighted = 1 (1 người, hệ số 1): vẫn phân bổ phần hệ số — khoá `total_weighted > 0`" do
      zone, period = build_pump_zone(name: "KV tw=1")
      unit = create(:unit, name: "ĐV tw=1", zone: zone)
      cp = create(:contact_point, :residential, name: "Đầu mối tw=1", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      # 1×1 = 1 > 0 → toàn bộ D về đơn vị → đầu mối duy nhất nhận 100.
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("100"))
    end

    it "total_weighted = 0 (quân số 0): bỏ qua phần hệ số, KHÔNG chia cho 0 — khoá `> 0` ↛ `>= 0`" do
      zone, period = build_pump_zone(name: "KV tw=0")
      unit = create(:unit, name: "ĐV tw=0", zone: zone)
      cp = create(:contact_point, :residential, name: "Đầu mối tw=0", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      expect(result.warnings).to include(zero_personnel_warning)
      expect(result.contact_point_allocations).to be_empty
    end

    it "đầu mối sinh hoạt nhận hệ số trực tiếp (có quân số): dùng đúng quân số — khoá `|| 0` ↛ `&& 0`" do
      zone, period = build_pump_zone(name: "KV cp-res")
      cp = create(:contact_point, :zone_residential, name: "Đầu mối trực tiếp", zone: zone,
                  initial_personnel_counts: { rank_for(period).id => 5 })
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      # 5×1 = 5 > 0 → đầu mối nhận toàn bộ D = 100.
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("100"))
    end

    it "đầu mối sinh hoạt trực tiếp KHÔNG quân số: nhận 0, không suy ra 1 — khoá `|| 0` ↛ `|| 1` (dòng 105)" do
      zone, period = build_pump_zone(name: "KV cp-res-0")
      cp = create(:contact_point, :zone_residential, name: "Đầu mối trực tiếp 0", zone: zone,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("0"))
      expect(result.warnings).to include(zero_personnel_warning)
    end

    it "đơn vị có đầu mối quân số 0: không cộng nhầm 1 vào tổng đơn vị / đối tượng — khoá `|| 0` ↛ `|| 1` (dòng 90 & 137)" do
      zone, period = build_pump_zone(name: "KV unit-0")
      unit = create(:unit, name: "ĐV unit-0", zone: zone)
      cp_full = create(:contact_point, :residential, name: "Đầu mối đủ quân số", unit: unit,
                       initial_personnel_counts: { rank_for(period).id => 3 })
      cp_zero = create(:contact_point, :residential, name: "Đầu mối 0 quân số", unit: unit,
                       initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp_zero.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      # tổng đơn vị = 3 (không phải 4) → cp_full nhận toàn bộ 100; cp_zero nhận 0.
      expect(result.contact_point_allocations[cp_full.id]).to eq(BigDecimal("100"))
      expect(result.contact_point_allocations[cp_zero.id]).to eq(BigDecimal("0"))
    end

    it "đầu mối ngoài biên chế nhận hệ số trực tiếp nhưng thiếu snapshot: nhận 0 — khoá `|| 0` ↛ `|| 1` (dòng 106)" do
      zone, period = build_pump_zone(name: "KV ne-0")
      cp = create(:contact_point, :non_establishment, name: "Thợ xây thiếu snapshot",
                  zone: zone, personnel_count: 5)
      NonEstablishmentSnapshot.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("0"))
      expect(result.warnings).to include(zero_personnel_warning)
    end

    it "đầu mối công cộng thuộc khu vực nhận hệ số trực tiếp: quân số coi như 0 — khoá `else 0` ↛ `else 1` (dòng 107)" do
      zone, period = build_pump_zone(name: "KV public")
      cp = ContactPoint.create!(name: "Đèn đường nhận hệ số", contact_point_type: "public",
                                zone: zone, unit: nil)
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("0"))
      expect(result.warnings).to include(zero_personnel_warning)
    end

    it "allocation with neither unit_id nor contact_point_id returns 0 personnel (line 121)" do
      zone, period = build_pump_zone(name: "KV orphan")
      # Bypass XOR validation to exercise the defensive guard
      alloc = PumpAllocation.new(zone: zone, period: period, unit_id: nil,
                                 contact_point_id: nil, coefficient: BigDecimal("1"),
                                 fixed_percentage: nil)
      alloc.save!(validate: false)

      result = call_pump(zone, period)
      expect(result.warnings).to include(zero_personnel_warning)
      expect(result.contact_point_allocations).to be_empty
    end

    it "unit-based allocation where all residential CPs have zero personnel skips distribution (line 134)" do
      zone, period = build_pump_zone(name: "KV unit-all-zero")
      unit = create(:unit, name: "ĐV all-zero", zone: zone)
      cp = create(:contact_point, :residential, name: "Đầu mối zero", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      # Use fixed_percentage so the amount is non-zero despite zero personnel
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: BigDecimal("50"), coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      # unit_total = 0 => distribute_to_residential_contact_points skips this unit
      # cp_amounts hash returns BigDecimal("0") for unset keys
      expect(result.contact_point_allocations).not_to have_key(cp.id)
    end

    it "direct contact-point-level allocation distributes amount directly (line 141)" do
      zone, period = build_pump_zone(name: "KV cp-direct")
      cp = create(:contact_point, :zone_residential, name: "Đầu mối trực tiếp fixed", zone: zone,
                  initial_personnel_counts: { rank_for(period).id => 3 })
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: BigDecimal("100"), coefficient: BigDecimal("1"))

      result = call_pump(zone, period)
      # 100% of D = 100 goes directly to this CP via the contact_point branch
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("100"))
    end

    it "kỳ đã đóng: vẫn tính phân bổ của đầu mối đã discard — khoá `unless closed?` ↛ `if closed?`" do
      zone, period = build_pump_zone(name: "KV closed")
      unit = create(:unit, name: "ĐV closed", zone: zone)
      cp_unit = create(:contact_point, :residential, name: "Đầu mối đơn vị closed", unit: unit,
                       initial_personnel_counts: { rank_for(period).id => 5 })
      direct_cp = ContactPoint.create!(name: "Đầu mối trực tiếp discard",
                                       contact_point_type: "public", zone: zone, unit: nil)
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: nil, coefficient: BigDecimal("1"))
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: direct_cp,
             fixed_percentage: BigDecimal("40"), coefficient: BigDecimal("1"))

      period.update!(closed: true) # Period.current → nil
      direct_cp.discard            # không có kỳ mở → không cleanup → giữ pump_allocation

      result = call_pump(zone, period)
      # Kỳ đã đóng giữ phân bổ đầu mối discard: trực tiếp 40% = 40; còn lại 60 về đơn vị.
      expect(result.contact_point_allocations[direct_cp.id]).to eq(BigDecimal("40"))
      expect(result.contact_point_allocations[cp_unit.id]).to eq(BigDecimal("60"))
    end
  end
end
