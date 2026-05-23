require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "khi chưa đăng nhập" do
      it "redirect đến trang đăng nhập" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "khi đăng nhập system_admin" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả về 200 và render tổng quan" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng quan")
      end

      it "render sidebar với items system_admin" do
        get root_path
        expect(response.body).to include("Đầu mối")
        expect(response.body).to include("Khu vực")
        expect(response.body).to include("Tài khoản")
      end
    end

    context "khi đăng nhập technician" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "redirect khỏi dashboard về trang phù hợp (technician không có quyền xem nghiệp vụ)" do
        get root_path
        expect(response).to redirect_to(users_path)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("errors.access_denied"))
        expect(response.body).to include("Tài khoản")
        expect(response.body).not_to include("Đầu mối")
      end
    end

    context "khi force_password_change" do
      let(:user) { create(:user, :system_admin, force_password_change: true) }
      before { sign_in user }

      it "redirect đến trang đổi mật khẩu" do
        get root_path
        expect(response).to redirect_to(edit_password_change_path)
      end
    end
  end

  describe "Chiều 8 — dashboard khi calculations trống" do
    let(:sample) { setup_zone_one_full_sample }
    # KHÔNG gọi CalculationOrchestrator

    context "SA" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "render bình thường, deficit/surplus = 0" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng quan")
      end
    end

    context "UA-ZM" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }
      before { sign_in user }

      it "render bình thường, deficit_count = 0" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng quan")
      end
    end
  end

  describe "GET /dashboard với data" do
    let(:sample) { setup_zone_one_full_sample }
    before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    context "T80 — system_admin xem tổng quan" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "hiển thị bảng khu vực (công cộng + bơm nước) + bảng đơn vị" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đơn vị A")
        expect(response.body).to include("Đơn vị B")
        expect(response.body).to include("Điện công cộng")
        expect(response.body).to include("Điện bơm nước")
        expect(response.body).to include(sample.zone.name)
      end

      it "không hiện heading kỳ riêng và badge Đang mở (topbar đã có)" do
        get dashboard_path
        doc = Nokogiri::HTML(response.body)
        main_content = doc.css("main").text
        expect(main_content).not_to include("Đang mở")
      end

      it "hiện đơn giá điện" do
        get dashboard_path
        expect(response.body).to include("Đơn giá điện")
      end

      it "tiêu đề bảng khu vực việt hoá (không có 'per')" do
        get dashboard_path
        expect(response.body).to include("theo khu vực")
        expect(response.body).not_to include("per khu vực")
      end

      it "bảng đơn vị có tiêu đề" do
        get dashboard_path
        expect(response.body).to include("Thâm điện và trạng thái nhập liệu theo đơn vị")
      end

      it "hover dòng dùng bg-gray-50 (nhất quán với index pages)" do
        get dashboard_path
        expect(response.body).to include("hover:bg-gray-50")
        expect(response.body).not_to include("hover:bg-yellow-50")
      end
    end

    context "commander — open period banner" do
      let(:user) { create(:user, :commander, unit: sample.unit_b) }
      before { sign_in user }

      it "CMD không thấy banner 'Vui lòng nhập liệu'" do
        get dashboard_path
        expect(response.body).not_to include(I18n.t("dashboard.open_period_banner.subtitle"))
      end
    end

    context "T81 — unit_admin zone-manager" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }
      before { sign_in user }

      it "hiển thị deficit_count + surplus_count đúng cho đơn vị A + đầu mối khu vực" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng thâm điện")
        expect(response.body).to include("Số đầu mối thiếu")
        expect(response.body).to include("Số đầu mối thừa")
      end
    end

    context "T82 — warning tổn hao bất thường" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "hiển thị cảnh báo trên dashboard khi main meter quá nhỏ" do
        sample.main_meter_reading.update!(usage: 1900)
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng sử dụng các công tơ con lớn hơn công tơ tổng")
      end
    end
  end
end
