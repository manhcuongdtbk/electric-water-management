require "rails_helper"

RSpec.describe PumpAllocationCalculator do
  # CHIEU-phan-bo-tram-ky-cu: kỳ cũ (per_station = false) gộp toàn khu vực không đổi
  # (T02 dữ liệu mẫu + nhánh legacy pin per_station=false của mutation #376, bên dưới).
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
      # Các test #376 nhắm nhánh zone-wide (allocation cấp đối tượng, không gắn trạm).
      # Ép kỳ về legacy để giữ ngữ nghĩa zone-wide khi kỳ mới mặc định per-station.
      period.update!(pump_allocation_per_station: false)
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

    # CHIEU-phan-bo-tram-config-completeness (#401): còn điện thừa nhưng total_weighted = 0
    # → KHÔNG chia cho 0, KHÔNG bỏ rơi điện âm thầm; chặn tính toán với lỗi rõ. Vẫn khoá
    # `> 0` ↛ `>= 0` (nếu `>= 0` thì chia 0/0 thay vì chặn).
    it "total_weighted = 0 (quân số 0): chặn tính toán thay vì bỏ rơi điện — khoá `> 0` ↛ `>= 0`" do
      zone, period = build_pump_zone(name: "KV tw=0")
      unit = create(:unit, name: "ĐV tw=0", zone: zone)
      cp = create(:contact_point, :residential, name: "Đầu mối tw=0", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig)
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

    # Đầu mối hệ số trực tiếp không quân số → trọng số 0 (không suy ra 1, khoá `|| 0` ↛ `|| 1`
    # dòng `personnel.zero?`). Vì là recipient hệ số DUY NHẤT → total_weighted = 0 → chặn (#401).
    it "đầu mối sinh hoạt trực tiếp KHÔNG quân số: trọng số 0 (không suy ra 1) → chặn — khoá `|| 0` ↛ `|| 1`" do
      zone, period = build_pump_zone(name: "KV cp-res-0")
      cp = create(:contact_point, :zone_residential, name: "Đầu mối trực tiếp 0", zone: zone,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig)
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

    # Ngoài biên chế thiếu snapshot → quân số 0 (khoá `|| 0` ↛ `|| 1`); là recipient hệ số
    # duy nhất → total_weighted = 0 → chặn (#401).
    it "đầu mối ngoài biên chế nhận hệ số trực tiếp nhưng thiếu snapshot: quân số 0 → chặn — khoá `|| 0` ↛ `|| 1`" do
      zone, period = build_pump_zone(name: "KV ne-0")
      cp = create(:contact_point, :non_establishment, name: "Thợ xây thiếu snapshot",
                  zone: zone, personnel_count: 5)
      NonEstablishmentSnapshot.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
             fixed_percentage: nil, coefficient: BigDecimal("1"))

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig)
    end



    it "allocation with neither unit_id nor contact_point_id raises IncompleteStationConfig (#401)" do
      zone, period = build_pump_zone(name: "KV orphan")
      alloc = PumpAllocation.new(zone: zone, period: period, unit_id: nil,
                                 contact_point_id: nil, coefficient: BigDecimal("1"),
                                 fixed_percentage: nil)
      alloc.save!(validate: false)

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig)
    end

    it "unit-based allocation where all residential CPs have zero personnel raises IncompleteStationConfig (#401)" do
      zone, period = build_pump_zone(name: "KV unit-all-zero")
      unit = create(:unit, name: "ĐV all-zero", zone: zone)
      cp = create(:contact_point, :residential, name: "Đầu mối zero", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all
      create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil,
             fixed_percentage: BigDecimal("50"), coefficient: BigDecimal("1"))

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig)
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

    # CHIEU-phan-bo-tram-da-xoa: recipient đã Discard trên kỳ đã đóng vẫn được tính
    # (nhánh legacy giữ example này; nhánh per-trạm có example tương ứng bên dưới).
    it "kỳ đã đóng: vẫn tính phân bổ của đầu mối đã discard — khoá `unless closed?` ↛ `if closed?`" do
      zone, period = build_pump_zone(name: "KV closed")
      unit = create(:unit, name: "ĐV closed", zone: zone)
      cp_unit = create(:contact_point, :residential, name: "Đầu mối đơn vị closed", unit: unit,
                       initial_personnel_counts: { rank_for(period).id => 5 })
      direct_cp = ContactPoint.create!(name: "Đầu mối trực tiếp discard",
                                       contact_point_type: "non_establishment", zone: zone,
                                       unit: nil, personnel_count: 3)
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

  describe "#call — per-trạm (TN2)" do
    def open_per_station_period
      PeriodService.new.open_new_period(year: 2031, month: 1, unit_price: BigDecimal("2000")).period
    end

    def call_pump(zone, period)
      loss = LossCalculator.new(zone: zone, period: period).call
      PumpAllocationCalculator.new(zone: zone, period: period, loss_results: loss).call
    end

    def rank_for(period)
      period.ranks.order(:position).first
    end

    # CHIEU-phan-bo-tram-tong: hai trạm, recipient riêng; Σ per-trạm = D toàn khu vực.
    it "hai trạm có recipient riêng; tổng phân bổ mỗi trạm = D_trạm; tổng = D toàn khu vực" do
      zone = create(:zone, name: "KV hai trạm")
      period = open_per_station_period
      expect(period.pump_allocation_per_station).to be(true)

      station_a = create(:contact_point, :water_pump, name: "Trạm A", zone: zone)
      station_b = create(:contact_point, :water_pump, name: "Trạm B", zone: zone)
      meter_a = create(:meter, name: "CT-A", contact_point: station_a, no_loss: true)
      meter_b = create(:meter, name: "CT-B", contact_point: station_b, no_loss: true)
      meter_a.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
      meter_b.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 60)

      unit_a = create(:unit, name: "ĐV A", zone: zone)
      cp_a = create(:contact_point, :residential, name: "Đầu mối A", unit: unit_a,
                    initial_personnel_counts: { rank_for(period).id => 1 })
      unit_b = create(:unit, name: "ĐV B", zone: zone)
      cp_b = create(:contact_point, :residential, name: "Đầu mối B", unit: unit_b,
                    initial_personnel_counts: { rank_for(period).id => 1 })

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
             unit: unit_a, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_b,
             unit: unit_b, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      expect(result.total_d).to eq(BigDecimal("160"))
      expect(result.contact_point_allocations[cp_a.id]).to eq(BigDecimal("100"))
      expect(result.contact_point_allocations[cp_b.id]).to eq(BigDecimal("60"))
      total = result.contact_point_allocations.values.sum(BigDecimal("0"))
      expect(total).to eq(BigDecimal("160"))

      # CHIEU-phan-bo-tram-tong: per-(cp × trạm) breakdown khớp từng trạm.
      expect(result.contact_point_station_allocations[cp_a.id]).to eq(station_a.id => BigDecimal("100"))
      expect(result.contact_point_station_allocations[cp_b.id]).to eq(station_b.id => BigDecimal("60"))

      # Breakdown cộng theo cp = tổng contact_point_allocations của cp đó.
      result.contact_point_station_allocations.each do |cp_id, by_station|
        expect(by_station.values.sum(BigDecimal("0"))).to eq(result.contact_point_allocations[cp_id])
      end
    end

    # CHIEU-phan-bo-tram-tong: nhánh legacy (gộp toàn khu vực) không có per-trạm detail.
    it "nhánh legacy (gộp toàn khu vực) → contact_point_station_allocations rỗng" do
      zone = create(:zone, name: "KV legacy breakdown")
      period = open_per_station_period
      period.update!(pump_allocation_per_station: false)

      station = create(:contact_point, :water_pump, name: "Trạm legacy", zone: zone)
      meter = create(:meter, name: "CT-legacy", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

      unit = create(:unit, name: "ĐV legacy", zone: zone)
      cp = create(:contact_point, :residential, name: "ĐM legacy", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: nil,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("100"))
      expect(result.contact_point_station_allocations).to eq({})
    end

    # CHIEU-phan-bo-tram-chua-cau-hinh: trạm chưa cấu hình recipient → cảnh báo, không chặn.
    it "trạm chưa có recipient → cảnh báo, không chặn" do
      zone = create(:zone, name: "KV trạm trống")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm cô đơn", zone: zone)
      meter = create(:meter, name: "CT-CD", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 50)

      result = call_pump(zone, period)
      expect(result.warnings).to include(
        I18n.t("services.pump_allocation_calculator.warnings.station_without_recipient", station: "Trạm cô đơn")
      )
      expect(result.total_d).to eq(BigDecimal("50"))
    end

    # CHIEU-phan-bo-tram-bon-recipient: recipient khối chia xuống đầu mối residential
    # (đơn vị/nhóm/đầu mối là ba loại recipient còn lại; xem pump_allocation_spec.rb).
    it "recipient khối: chia xuống đầu mối residential trong khối theo quân số" do
      zone = create(:zone, name: "KV khối")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm khối", zone: zone)
      meter = create(:meter, name: "CT-K", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 90)

      unit = create(:unit, name: "ĐV khối", zone: zone)
      block = create(:block, name: "Khối X", unit: unit)
      cp1 = create(:contact_point, :residential, name: "ĐM1", unit: unit, block: block,
                   initial_personnel_counts: { rank_for(period).id => 2 })
      cp2 = create(:contact_point, :residential, name: "ĐM2", unit: unit, block: block,
                   initial_personnel_counts: { rank_for(period).id => 1 })

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: nil, contact_point: nil, block: block, group: nil, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp1.id]).to eq(BigDecimal("60"))
      expect(result.contact_point_allocations[cp2.id]).to eq(BigDecimal("30"))
    end

    # CHIEU-phan-bo-tram-bon-recipient: recipient nhóm chia xuống đầu mối residential
    # trong nhóm theo quân số (nhánh group_id của personnel_count_for + distribute_to_recipients).
    it "recipient nhóm: chia xuống đầu mối residential trong nhóm theo quân số" do
      zone = create(:zone, name: "KV nhóm")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm nhóm", zone: zone)
      meter = create(:meter, name: "CT-N", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 80)

      unit = create(:unit, name: "ĐV nhóm", zone: zone)
      group = create(:group, name: "Nhóm Y", unit: unit)
      cp1 = create(:contact_point, :residential, name: "ĐM-N1", unit: unit, group: group,
                   initial_personnel_counts: { rank_for(period).id => 3 })
      cp2 = create(:contact_point, :residential, name: "ĐM-N2", unit: unit, group: group,
                   initial_personnel_counts: { rank_for(period).id => 1 })

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: nil, contact_point: nil, block: nil, group: group, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp1.id]).to eq(BigDecimal("60"))
      expect(result.contact_point_allocations[cp2.id]).to eq(BigDecimal("20"))
    end

    # CHIEU-phan-bo-tram-config-completeness (#401): nhóm hệ số duy nhất nhưng quân số 0
    # → total_weighted = 0, còn điện thừa → chặn tính toán (không bỏ rơi điện của trạm).
    it "recipient nhóm hệ số duy nhất rỗng quân số: chặn tính toán (#401)" do
      zone = create(:zone, name: "KV nhóm rỗng")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm nhóm rỗng", zone: zone)
      meter = create(:meter, name: "CT-NR", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 50)

      unit = create(:unit, name: "ĐV nhóm rỗng", zone: zone)
      group = create(:group, name: "Nhóm rỗng", unit: unit)
      cp = create(:contact_point, :residential, name: "ĐM-rỗng", unit: unit, group: group,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      PersonnelEntry.where(contact_point_id: cp.id, period_id: period.id).delete_all

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: nil, contact_point: nil, block: nil, group: group, coefficient: 1, fixed_percentage: nil)

      expect { call_pump(zone, period) }
        .to raise_error(PumpAllocationCalculator::IncompleteStationConfig,
                        /Trạm bơm Trạm nhóm rỗng chưa phân bổ hết điện/)
    end

    # CHIEU-phan-bo-tram-bon-recipient: đầu mối ngoài biên chế (non_establishment) nhận hệ số
    # trực tiếp khi CÓ NonEstablishmentSnapshot (personnel_count) → nhận phần weighted đúng.
    # (Các test #401 chỉ phủ nhánh thiếu snapshot → 0 → chặn; đây là happy path.)
    it "đầu mối ngoài biên chế CÓ snapshot: nhận phần hệ số theo quân số snapshot" do
      zone = create(:zone, name: "KV ne happy")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm ne", zone: zone)
      meter = create(:meter, name: "CT-ne", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

      # CP ngoài biên chế: PeriodService tự tạo snapshot khi kỳ mở (personnel_count = 5).
      ne_cp = create(:contact_point, :non_establishment, name: "Thợ xây ne", zone: zone,
                     personnel_count: 5)
      expect(NonEstablishmentSnapshot.find_by(contact_point: ne_cp, period: period)
               &.personnel_count).to eq(5)
      # Đầu mối residential thuộc đơn vị để chia phần weighted: ne 5 + res 5 = 10 trọng số.
      unit = create(:unit, name: "ĐV ne", zone: zone)
      res_cp = create(:contact_point, :residential, name: "ĐM ne", unit: unit,
                      initial_personnel_counts: { rank_for(period).id => 5 })

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: nil, contact_point: ne_cp, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      # ne 5×1 / (5+5) × 100 = 50; res cũng 50.
      expect(result.contact_point_allocations[ne_cp.id]).to eq(BigDecimal("50"))
      expect(result.contact_point_allocations[res_cp.id]).to eq(BigDecimal("50"))
    end

    # CHIEU-phan-bo-tram-bon-recipient: đầu mối residential THUỘC ĐƠN VỊ (unit-level) làm
    # recipient `contact_point` trực tiếp → nhận thẳng phần của mình (không qua rollup đơn vị).
    # (Test trực tiếp hiện có dùng CP zone-level; đây là biến thể unit-level.)
    it "đầu mối residential unit-level làm recipient trực tiếp: nhận thẳng phần của mình" do
      zone = create(:zone, name: "KV cp unit-level")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm cp unit", zone: zone)
      meter = create(:meter, name: "CT-cpu", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

      unit = create(:unit, name: "ĐV cp unit", zone: zone)
      unit_cp = create(:contact_point, :residential, name: "ĐM unit-level trực tiếp", unit: unit,
                       initial_personnel_counts: { rank_for(period).id => 5 })
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: nil, contact_point: unit_cp, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

      result = call_pump(zone, period)
      # Recipient hệ số duy nhất, quân số 5 > 0 → nhận toàn bộ D = 100 trực tiếp.
      expect(result.contact_point_allocations[unit_cp.id]).to eq(BigDecimal("100"))
    end

    # CHIEU-phan-bo-tram-recipient-rong: đầu mối sinh hoạt bị xóa SAU khi cấu hình
    # → khi tính toán, bỏ qua phân phối cho đối tượng đó + cảnh báo (§27.5).
    it "đối tượng nhận rỗng (đầu mối bị xóa sau cấu hình): bỏ qua phân phối + cảnh báo" do
      zone = create(:zone, name: "KV recipient rỗng")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm rỗng", zone: zone)
      meter = create(:meter, name: "CT-rỗng", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

      unit_ok = create(:unit, name: "ĐV có người", zone: zone)
      create(:contact_point, :residential, name: "ĐM có", unit: unit_ok,
             initial_personnel_counts: { rank_for(period).id => 5 })

      unit_empty = create(:unit, name: "ĐV rỗng", zone: zone)
      cp_gone = create(:contact_point, :residential, name: "ĐM sẽ xóa", unit: unit_empty,
                       initial_personnel_counts: { rank_for(period).id => 1 })

      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit_ok, coefficient: 1)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit_empty, fixed_percentage: BigDecimal("30"))

      # Xóa đầu mối sau khi đã cấu hình — cleanup kỳ đang mở xóa personnel_entry
      cp_gone.discard!
      PersonnelEntry.where(contact_point_id: cp_gone.id, period_id: period.id).delete_all

      result = call_pump(zone, period)
      expect(result.warnings).to include(
        I18n.t("services.pump_allocation_calculator.warnings.empty_recipient", name: "ĐV rỗng")
      )
      # Đơn vị rỗng nhận 30% cố định = 30 kW nhưng không phân phối được
      expect(result.contact_point_allocations).not_to have_key(cp_gone.id)
      # Đơn vị có người nhận phần còn lại 70% = 70 kW
      expect(result.contact_point_allocations.values.sum).to be > 0
    end

    it "kỳ đã đóng (theo từng trạm): vẫn tính cho đầu mối residential đã discard" do
      zone = create(:zone, name: "KV closed per-trạm")
      period = open_per_station_period
      station = create(:contact_point, :water_pump, name: "Trạm closed", zone: zone)
      meter = create(:meter, name: "CT-closed", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 70)

      unit = create(:unit, name: "ĐV closed", zone: zone)
      cp = create(:contact_point, :residential, name: "ĐM closed", unit: unit,
                  initial_personnel_counts: { rank_for(period).id => 1 })
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

      period.update!(closed: true)
      cp.discard

      result = call_pump(zone, period)
      expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("70"))
    end

    # CHIEU-phan-bo-tram-config-completeness (#401): trạm chỉ có recipient % cố định < 100%
    # và KHÔNG có recipient hệ số → còn điện thừa không ai nhận → chặn tính toán (không bỏ
    # rơi điện âm thầm, bảng tính tiền không nói dối).
    context "config-completeness per-trạm (#401)" do
      it "trạm chỉ có % cố định < 100%, không có recipient hệ số → chặn với lỗi nêu tên trạm" do
        zone = create(:zone, name: "KV thiếu hệ số")
        period = open_per_station_period
        station = create(:contact_point, :water_pump, name: "Trạm thiếu", zone: zone)
        meter = create(:meter, name: "CT-T", contact_point: station, no_loss: true)
        meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

        unit = create(:unit, name: "ĐV thiếu", zone: zone)
        create(:contact_point, :residential, name: "ĐM thiếu", unit: unit,
               initial_personnel_counts: { rank_for(period).id => 1 })
        create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
               unit: unit, contact_point: nil, block: nil, group: nil,
               fixed_percentage: BigDecimal("40"), coefficient: BigDecimal("1"))

        expect { call_pump(zone, period) }
          .to raise_error(PumpAllocationCalculator::IncompleteStationConfig,
                          /Trạm bơm Trạm thiếu chưa phân bổ hết điện/)
      end

      it "trạm phủ kín 100% bằng % cố định (không cần hệ số) → KHÔNG chặn" do
        zone = create(:zone, name: "KV đủ 100%")
        period = open_per_station_period
        station = create(:contact_point, :water_pump, name: "Trạm đủ", zone: zone)
        meter = create(:meter, name: "CT-D", contact_point: station, no_loss: true)
        meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

        cp = create(:contact_point, :zone_residential, name: "ĐM đủ 100%", zone: zone)
        create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
               unit: nil, contact_point: cp, block: nil, group: nil,
               fixed_percentage: BigDecimal("100"), coefficient: BigDecimal("1"))

        result = call_pump(zone, period)
        expect(result.contact_point_allocations[cp.id]).to eq(BigDecimal("100"))
      end

      it "trạm có recipient hệ số hợp lệ → KHÔNG chặn (cấu hình đầy đủ)" do
        zone = create(:zone, name: "KV đủ hệ số")
        period = open_per_station_period
        station = create(:contact_point, :water_pump, name: "Trạm hệ số", zone: zone)
        meter = create(:meter, name: "CT-H", contact_point: station, no_loss: true)
        meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)

        unit = create(:unit, name: "ĐV hệ số", zone: zone)
        cp = create(:contact_point, :residential, name: "ĐM hệ số", unit: unit,
                    initial_personnel_counts: { rank_for(period).id => 1 })
        create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
               unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

        expect { call_pump(zone, period) }.not_to raise_error
      end
    end
  end
end
