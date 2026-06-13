require "rails_helper"

RSpec.describe SummaryCalculator do
  describe "#call — T03 (dữ liệu mẫu mục 1)" do
    let(:sample) { setup_zone_one_full_sample }
    let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }
    let(:pump_results) {
      PumpAllocationCalculator.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
    }
    let(:result) {
      described_class.new(zone: sample.zone, period: sample.period,
                          loss_results: loss_results, pump_results: pump_results).call
    }

    before { result }

    def calculation_for(cp_key)
      Calculation.find_by(contact_point_id: sample.contact_points[cp_key].id, period: sample.period)
    end

    describe "Ban Tác huấn (Đơn vị A)" do
      let(:calc) { calculation_for(:ban_tac_huan) }

      it "tổng quân số = 5" do
        expect(calc.total_personnel).to eq(5)
      end

      it "tiêu chuẩn sinh hoạt = 292" do
        expect(calc.residential_standard).to eq_display("292.00")
      end

      it "tiêu chuẩn bơm nước = 47,25" do
        expect(calc.water_pump_standard).to eq_display("47.25")
      end

      it "tổng tiêu chuẩn = 339,25" do
        expect(calc.total_standard).to eq_display("339.25")
      end

      it "tiết kiệm của Bộ = 16,96" do
        expect(calc.savings_deduction).to eq_display("16.96")
      end

      it "tổn hao = 7,77" do
        expect(calc.loss_deduction).to eq_display("7.77")
      end

      it "công cộng Sư đoàn = 33,93" do
        expect(calc.division_public_deduction).to eq_display("33.93")
      end

      it "công cộng đơn vị = 10,18 (3%)" do
        expect(calc.unit_public_deduction).to eq_display("10.18")
      end

      it "Khác = 5,00 (số cụ thể)" do
        expect(calc.other_deduction).to eq_display("5.00")
      end

      it "tổng trừ = 73,84" do
        expect(calc.total_deduction).to eq_display("73.84")
      end

      it "tiêu chuẩn còn lại = 265,41" do
        expect(calc.remaining_standard).to eq_display("265.41")
      end

      it "sử dụng sinh hoạt = 250,00" do
        expect(calc.residential_usage).to eq_display("250.00")
      end

      it "sử dụng bơm nước = 52,65" do
        expect(calc.water_pump_usage).to eq_display("52.65")
      end

      it "tổng sử dụng = 302,65" do
        expect(calc.total_usage).to eq_display("302.65")
      end

      it "thiếu = 37,24" do
        expect(calc.deficit).to eq_display("37.24")
        expect(calc.surplus).to eq(0)
      end

      it "thành tiền thiếu = 87.004 đồng" do
        expect(calc.deficit_amount).to eq_money("87004")
      end
    end

    describe "Văn thư (Đơn vị A) — cột Khác âm" do
      let(:calc) { calculation_for(:van_thu) }

      it "tiêu chuẩn sinh hoạt = 234,00" do
        expect(calc.residential_standard).to eq_display("234.00")
      end

      it "cột Khác = -5 (hệ số × quân số)" do
        expect(calc.other_deduction).to eq_display("-5.00")
      end

      it "tổng trừ = 46,12" do
        expect(calc.total_deduction).to eq_display("46.12")
      end

      it "tiêu chuẩn còn lại = 206,78" do
        expect(calc.remaining_standard).to eq_display("206.78")
      end

      it "thừa = 5,72" do
        expect(calc.surplus).to eq_display("5.72")
        expect(calc.deficit).to eq(0)
      end
    end

    describe "Kho vật tư (Đơn vị A) — không tổn hao" do
      let(:calc) { calculation_for(:kho_vat_tu) }

      it "tổn hao = 0" do
        expect(calc.loss_deduction).to eq(0)
      end

      it "tiêu chuẩn còn lại = 169,21" do
        expect(calc.remaining_standard).to eq_display("169.21")
      end

      it "thừa = 27,62" do
        expect(calc.surplus).to eq_display("27.62")
      end
    end

    describe "Đại đội 1 (Đơn vị B) — công cộng đơn vị 0%, Khác hệ số dương" do
      let(:calc) { calculation_for(:dai_doi_1) }

      it "công cộng đơn vị = 0" do
        expect(calc.unit_public_deduction).to eq(0)
      end

      it "Khác = 33 (3 × 11)" do
        expect(calc.other_deduction).to eq_display("33.00")
      end

      it "thiếu = 106,86" do
        expect(calc.deficit).to eq_display("106.86")
      end

      it "thành tiền thiếu = 249.659 đồng" do
        expect(calc.deficit_amount).to eq_money("249659")
      end
    end

    describe "Văn thư (Đơn vị A) — cột Khác hệ số (đơn vị)" do
      before do
        apply_other_deduction(sample.contact_points[:van_thu], sample.period,
                              type: "unit_coefficient", value: -2)
        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
      end

      it "CHIEU-khac-don-vi-dau: khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối)" do
        # -2 × (10 − 2) = -16
        calc = calculation_for(:van_thu)
        expect(calc.other_deduction).to eq_display("-16.00")
      end
    end

    describe "Kho vật tư (Đơn vị A) — cột Khác hệ số (đơn vị) dương" do
      before do
        apply_other_deduction(sample.contact_points[:kho_vat_tu], sample.period,
                              type: "unit_coefficient", value: 2)
        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
      end

      it "CHIEU-khac-don-vi-dau: khoản trừ = hệ số dương × (tổng quân số đơn vị − quân số đầu mối)" do
        # 2 × (10 − 3) = 14
        calc = calculation_for(:kho_vat_tu)
        expect(calc.other_deduction).to eq_display("14.00")
      end
    end

    describe "Văn thư (Đơn vị A) — unit_coefficient tự tính lại khi đổi quân số đầu mối khác" do
      # Ban Tác huấn: tieu_doan_dai_doi=2, ha_si_quan=3 → 5 người ban đầu
      # Văn thư: co_quan=1, ha_si_quan=1 → 2 người (không đổi)
      # Kho vật tư: chi_huy_dai_doi=1, ha_si_quan=2 → 3 người (không đổi)
      # Đơn vị A tổng = 10; sau khi tăng Ban Tác huấn +3 → 13

      let(:ban) { sample.contact_points[:ban_tac_huan] }
      let(:van_thu) { sample.contact_points[:van_thu] }
      let(:ha_si_quan_rank) { sample.ranks[:ha_si_quan] }

      before do
        apply_other_deduction(van_thu, sample.period, type: "unit_coefficient", value: -2)
      end

      it "khoản trừ ban đầu = -2 × (10 − 2) = -16,00" do
        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
        calc = calculation_for(:van_thu)
        expect(calc.other_deduction).to eq_display("-16.00")
      end

      it "CHIEU-khac-don-vi-tu-tinh-lai: khoản trừ tự cập nhật = -2 × (13 − 2) = -22,00 sau khi quân số Ban Tác huấn tăng thêm 3" do
        # Tăng ha_si_quan của Ban Tác huấn từ 3 → 6 (đơn vị A: 10 → 13)
        entry = PersonnelEntry.find_by!(contact_point: ban, period: sample.period,
                                       rank: ha_si_quan_rank)
        entry.update!(count: 6)

        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
        calc = calculation_for(:van_thu)
        # -2 × (13 − 2) = -22
        expect(calc.other_deduction).to eq_display("-22.00")
      end
    end

    describe "Đại đội 1 (Đơn vị B) — cột Khác hệ số (đơn vị) một đầu mối sinh hoạt" do
      before do
        # Đơn vị B chỉ có một đầu mối sinh hoạt (dai_doi_1, 11 người).
        # unit_coefficient: hệ số × (tổng − bản thân) = hệ số × (11 − 11) = 0
        apply_other_deduction(sample.contact_points[:dai_doi_1], sample.period,
                              type: "unit_coefficient", value: -5)
        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
      end

      it "CHIEU-khac-don-vi-mot-dau-moi: khoản trừ = 0 khi đơn vị chỉ có một đầu mối sinh hoạt" do
        # -5 × (11 − 11) = 0
        calc = calculation_for(:dai_doi_1)
        expect(calc.other_deduction).to eq_display("0.00")
      end
    end

    describe "Chỉ huy khu vực (thuộc khu vực — unit_id null)" do
      let(:calc) { calculation_for(:chi_huy_khu_vuc) }

      it "công cộng đơn vị = 0 (không có unit_config)" do
        expect(calc.unit_public_deduction).to eq(0)
      end

      it "tiêu chuẩn sinh hoạt = 570 (1 Đại tá × 570)" do
        expect(calc.residential_standard).to eq_display("570.00")
      end

      it "thiếu = 33,32" do
        expect(calc.deficit).to eq_display("33.32")
      end

      it "thành tiền thiếu = 77.855 đồng" do
        expect(calc.deficit_amount).to eq_money("77855")
      end
    end

    it "tạo đúng 5 Calculation records" do
      expect(Calculation.where(period: sample.period).count).to eq(5)
    end

    it "idempotent — gọi lại không tạo duplicate" do
      described_class.new(zone: sample.zone, period: sample.period,
                          loss_results: loss_results, pump_results: pump_results).call
      expect(Calculation.where(period: sample.period).count).to eq(5)
    end
  end

  describe "#call — đầu mối đã discard (v2.4.0)" do
    let(:sample) { setup_zone_one_full_sample }

    def run_summary(period)
      loss = LossCalculator.new(zone: sample.zone, period: period).call
      pump = PumpAllocationCalculator.new(zone: sample.zone, period: period, loss_results: loss).call
      described_class.new(zone: sample.zone, period: period,
                          loss_results: loss, pump_results: pump).call
    end

    it "không tạo lại Calculation cho đầu mối discard ở kỳ đang mở" do
      cp = sample.contact_points[:ban_tac_huan]
      run_summary(sample.period)
      expect(Calculation.where(contact_point: cp, period: sample.period)).to be_present

      cp.discard
      run_summary(sample.period)

      expect(Calculation.where(contact_point: cp, period: sample.period)).to be_empty
    end

    context "kỳ cũ (đã đóng)" do
      let(:sample) { setup_zone_one_full_sample(open_period: false) }

      it "vẫn tính Calculation cho đầu mối đã discard (có meter_readings kỳ đó)" do
        cp = sample.contact_points[:ban_tac_huan]
        cp.discard
        run_summary(sample.period)
        expect(Calculation.where(contact_point: cp, period: sample.period)).to be_present
      end
    end

    # Test 1: Discard ở kỳ đang mở loại quân số khỏi tổng đơn vị cho unit_coefficient
    describe "unit_coefficient — discard đầu mối ở kỳ đang mở cập nhật tổng quân số đơn vị" do
      # Đơn vị A: Ban Tác huấn 5 + Văn thư 2 + Kho vật tư 3 = 10
      # Văn thư: unit_coefficient -2 → -2 × (10 − 2) = -16,00
      # Sau khi discard Kho vật tư (3 người) trong kỳ đang mở:
      #   delete_current_period_records xóa personnel_entries của Kho vật tư
      #   → tổng Đơn vị A = 7 (5 + 2)
      #   → Văn thư: -2 × (7 − 2) = -10,00

      before do
        apply_other_deduction(sample.contact_points[:van_thu], sample.period,
                              type: "unit_coefficient", value: -2)
        run_summary(sample.period)
      end

      it "baseline: Văn thư other_deduction = -16,00 (trước khi discard)" do
        calc = Calculation.find_by!(contact_point: sample.contact_points[:van_thu],
                                    period: sample.period)
        expect(calc.other_deduction).to eq_display("-16.00")
      end

      it "sau khi discard Kho vật tư, other_deduction Văn thư = -10,00" do
        sample.contact_points[:kho_vat_tu].discard

        run_summary(sample.period)

        calc = Calculation.find_by!(contact_point: sample.contact_points[:van_thu],
                                    period: sample.period)
        # tổng đơn vị A = 10 − 3 = 7; -2 × (7 − 2) = -10
        expect(calc.other_deduction).to eq_display("-10.00")
      end

      it "quân số và hệ số Văn thư không thay đổi sau khi discard Kho vật tư" do
        sample.contact_points[:kho_vat_tu].discard
        run_summary(sample.period)

        calc = Calculation.find_by!(contact_point: sample.contact_points[:van_thu],
                                    period: sample.period)
        expect(calc.total_personnel).to eq(2)
      end
    end

    # Test 2: Kỳ cũ giữ quân số đầu mối đã xóa (historical fidelity)
    describe "unit_coefficient — kỳ cũ giữ nguyên quân số đầu mối đã discard sau đó" do
      # Kỳ N (sample.period): Văn thư unit_coefficient -2 → -2 × (10 − 2) = -16,00
      # Đóng N, mở N+1. Trong N+1, discard Kho vật tư:
      #   → xóa personnel_entries của N+1 (không ảnh hưởng N)
      # Tính lại SummaryCalculator cho kỳ N:
      #   ZoneQuery dùng with_discarded → vẫn thấy Kho vật tư, tổng N = 10
      #   → Văn thư kỳ N: -2 × (10 − 2) = -16,00 (không đổi)

      let(:period_n) { sample.period }

      before do
        apply_other_deduction(sample.contact_points[:van_thu], period_n,
                              type: "unit_coefficient", value: -2)
        run_summary(period_n)

        # Đóng kỳ N và mở N+1
        PeriodService.new.close_period(period_n)
        PeriodService.new.open_new_period
      end

      it "kỳ cũ: other_deduction Văn thư vẫn = -16,00 sau khi discard Kho vật tư ở kỳ mới" do
        sample.contact_points[:kho_vat_tu].discard

        # Tính lại cho kỳ cũ (period N)
        run_summary(period_n)

        calc = Calculation.find_by!(contact_point: sample.contact_points[:van_thu],
                                    period: period_n)
        # with_discarded → Kho vật tư vẫn đóng góp 3 người vào tổng kỳ N
        expect(calc.other_deduction).to eq_display("-16.00")
      end
    end
  end
end
