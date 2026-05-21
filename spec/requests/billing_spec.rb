require "rails_helper"

RSpec.describe "Billing", type: :request do
  let(:sample) { setup_zone_one_full_sample }

  describe "GET /billing" do
    before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    context "unguarded" do
      it "redirect khi chưa đăng nhập" do
        get billing_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "system_admin (T77)" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả 200 + render bảng tính tiền" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Bảng tính tiền")
        expect(response.body).to include("Khu vực 1")
      end

      it "hiển thị 30 cột khi xem gộp (Khu vực + Đơn vị)" do
        get billing_path
        expect(response.body).to include("Khu vực").and include("Đơn vị")
      end

      it "hiển thị tất cả đầu mối kể cả đầu mối thuộc khu vực" do
        get billing_path
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Đại đội 1")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      it "hiển thị dropdown chọn kỳ" do
        get billing_path
        expect(response.body).to include("Tháng #{sample.period.month}/#{sample.period.year}")
      end

      it "hiển thị dropdown khu vực và đơn vị" do
        get billing_path
        expect(response.body).to include("Tất cả khu vực")
        expect(response.body).to include("Tất cả đơn vị")
      end

      it "lọc theo khu vực" do
        get billing_path(zone_id: sample.zone.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
      end

      it "lọc theo đơn vị (không chọn khu vực)" do
        get billing_path(unit_id: sample.unit_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
      end

      it "xem kỳ cũ qua period_id" do
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get billing_path(period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đã đóng")
      end

      it "kỳ đã đóng → KHÔNG hiển thị nút tính toán lại" do
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get billing_path(period_id: sample.period.id)
        expect(response.body).not_to include("Tính toán lại")
      end
    end

    context "unit_admin zone-manager (T76)" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }
      before { sign_in user }

      it "thấy đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      it "KHÔNG thấy dropdown khu vực/đơn vị" do
        get billing_path
        expect(response.body).not_to include("Tất cả khu vực")
        expect(response.body).not_to include("Tất cả đơn vị")
      end

      it "hiển thị tên khu vực + tên đơn vị dạng cố định" do
        get billing_path
        expect(response.body).to include(sample.zone.name)
        expect(response.body).to include(sample.unit_a.name)
      end

      it "hiện cột Đơn vị trong bảng (29 cột — phân biệt đơn vị vs khu vực)" do
        get billing_path
        expect(response.body).to include("Đơn vị")
      end

      it "KHÔNG thấy đầu mối của đơn vị B" do
        get billing_path
        expect(response.body).not_to include("Đại đội 1")
      end
    end

    context "unit_admin không phải zone-manager" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_b) }
      before { sign_in user }

      it "chỉ thấy đầu mối Đơn vị B" do
        get billing_path
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
        expect(response.body).not_to include("Chỉ huy khu vực")
      end

      it "hiển thị tên khu vực + tên đơn vị dạng cố định" do
        get billing_path
        expect(response.body).to include(sample.zone.name)
        expect(response.body).to include(sample.unit_b.name)
      end
    end

    context "commander zone-manager (nghiệp vụ 6: tương tự UA-ZM)" do
      let(:user) { create(:user, :commander, unit: sample.unit_a) }
      before { sign_in user }

      it "thấy đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      it "hiển thị tên khu vực + tên đơn vị dạng cố định" do
        get billing_path
        expect(response.body).to include(sample.zone.name)
        expect(response.body).to include(sample.unit_a.name)
      end

      it "KHÔNG thấy dropdown khu vực/đơn vị" do
        get billing_path
        expect(response.body).not_to include("Tất cả khu vực")
      end
    end

    context "commander không phải zone-manager" do
      let(:user) { create(:user, :commander, unit: sample.unit_b) }
      before { sign_in user }

      it "chỉ thấy đầu mối đơn vị mình" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
        expect(response.body).not_to include("Chỉ huy khu vực")
      end

      it "hiển thị tên khu vực + tên đơn vị dạng cố định" do
        get billing_path
        expect(response.body).to include(sample.zone.name)
        expect(response.body).to include(sample.unit_b.name)
      end
    end

    context "technician" do
      let(:user) { create(:user, :technician) }
      before { sign_in user }

      it "redirect về users_path" do
        get billing_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "format :xlsx" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả về file xlsx" do
        get billing_path(format: :xlsx)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("spreadsheetml.sheet")
        expect(response.headers["Content-Disposition"]).to include("bang-tinh-tien")
      end

      it "export xlsx kỳ cũ" do
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get billing_path(period_id: sample.period.id, format: :xlsx)
        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Disposition"]).to include("bang-tinh-tien-#{sample.period.month}")
      end
    end
  end

  describe "POST /billing/recalculate" do
    let(:admin) { create(:user, :system_admin) }
    let(:unit_admin_b) { create(:user, :unit_admin, unit: sample.unit_b) }

    before do
      sample  # force setup
    end

    it "system_admin tính toán lại toàn hệ thống" do
      sign_in admin
      expect {
        post recalculate_billing_path
      }.to change { Calculation.where(period: sample.period).count }.from(0).to(5)
      expect(response).to redirect_to(billing_path)
    end

    it "commander KHÔNG có quyền recalculate" do
      commander = create(:user, :commander, unit: sample.unit_a)
      sign_in commander
      post recalculate_billing_path
      expect(response).to redirect_to(new_user_session_path).or redirect_to(root_path)
    end

    it "kỳ đã đóng → không cho tính toán lại" do
      sample.period.update!(closed: true)
      PeriodService.new.open_new_period(year: 2026, month: 6,
                                        unit_price: BigDecimal("2336.4"))
      sign_in admin
      post recalculate_billing_path(period_id: sample.period.id)
      expect(response).to redirect_to(billing_path(period_id: sample.period.id))
      expect(flash[:alert]).to include("đã đóng")
    end
  end
end
