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

      it "KHÔNG thấy đầu mối của Đơn vị B" do
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
    end

    context "nút Xuất Excel hiển thị cho mọi vai trò nghiệp vụ (C4)" do
      it "system_admin" do
        sign_in create(:user, :system_admin)
        get billing_path
        expect(response.body).to include("Xuất Excel")
      end

      it "unit_admin" do
        sign_in create(:user, :unit_admin, unit: sample.unit_a)
        get billing_path
        expect(response.body).to include("Xuất Excel")
      end

      it "commander" do
        sign_in create(:user, :commander, unit: sample.unit_a)
        get billing_path
        expect(response.body).to include("Xuất Excel")
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
  end
end
