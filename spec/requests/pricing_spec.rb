require "rails_helper"

RSpec.describe "Pricing", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "GET /pricing" do
    it "trả về 200 khi chưa có kỳ" do
      get pricing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mở kỳ mới")
    end

    it "hiển thị form sửa đơn giá khi có kỳ đang mở" do
      create(:period, year: 2026, month: 5, closed: false, unit_price: 2336.4)
      get pricing_path
      expect(response.body).to include("Kỳ đang mở")
      expect(response.body).to include("Lưu cập nhật")
    end

    it "cột đơn giá hiện đầy đủ (không làm tròn)" do
      create(:period, year: 2026, month: 5, closed: false, unit_price: 2336.4)
      get pricing_path
      # Bảng danh sách kỳ hiện "2.336,4 đ/kW" không phải "2.336 đ"
      expect(response.body).to include("2.336,4 đ/kW")
    end
  end

  describe "GET /pricing — phân trang và bộ lọc" do
    let!(:periods_2025) do
      (1..12).map { |m| create(:period, year: 2025, month: m, closed: true, unit_price: 2000) }
    end
    let!(:periods_2026) do
      (1..6).map { |m| create(:period, year: 2026, month: m, closed: m < 6, unit_price: 2336) }
    end
    let(:html) { Nokogiri::HTML(response.body) }

    it "hiển thị phân trang khi có hơn 25 kỳ" do
      (1..12).each { |m| create(:period, year: 2024, month: m, closed: true, unit_price: 1800) }
      get pricing_path
      expect(response).to have_http_status(:ok)
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(25)
      expect(html.css("nav.pagy").size).to be >= 1
    end

    it "lọc theo năm chỉ hiển thị các kỳ trong năm đó" do
      get pricing_path, params: { year: 2025 }
      expect(response).to have_http_status(:ok)
      rows = html.css("table tbody tr")
      rows.each do |row|
        expect(row.text).to include("2025")
      end
      expect(response.body).not_to include("Tháng 6/2026")
    end

    it "chọn Tất cả hiển thị mọi kỳ (phân trang)" do
      get pricing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tổng: 18 bản ghi")
    end

    it "thay đổi per_page hiển thị đúng số dòng" do
      get pricing_path, params: { per_page: 25 }
      expect(response).to have_http_status(:ok)
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(18)
    end

    it "year filter và per_page giữ lại giá trị của nhau" do
      get pricing_path, params: { year: 2025, per_page: 25 }
      expect(response).to have_http_status(:ok)
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(12)
      rows.each do |row|
        expect(row.text).to include("2025")
      end
    end

    it "tổng số bản ghi cập nhật đúng khi lọc theo năm" do
      get pricing_path, params: { year: 2025 }
      expect(response.body).to include("Tổng: 12 bản ghi")

      get pricing_path, params: { year: 2026 }
      expect(response.body).to include("Tổng: 6 bản ghi")
    end

    it "dropdown năm chứa các năm có dữ liệu" do
      get pricing_path
      expect(html.css("select#year option").map(&:text)).to include("Tất cả", "2026", "2025")
    end

    it "dropdown per_page hiển thị giá trị đã chọn" do
      get pricing_path, params: { per_page: 50 }
      selected = html.css("select#per_page option[selected]")
      expect(selected.first&.text).to eq("50")
    end
  end

  describe "POST /pricing/open_period" do
    it "mở kỳ đầu tiên với year/month/unit_price" do
      post open_period_pricing_path, params: { year: "2026", month: "5", unit_price: "2336.4" }
      expect(response).to redirect_to(pricing_path)
      expect(Period.current).to be_present
      expect(Period.current.unit_price.to_s).to eq("2336.4")
    end

    it "không cho mở khi đã có kỳ đang mở" do
      create(:period, year: 2026, month: 5, closed: false)
      post open_period_pricing_path, params: { year: "2026", month: "6", unit_price: "2500" }
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /pricing — cảnh báo đóng kỳ" do
    let!(:period) { create(:period, year: 2026, month: 6, closed: false, unit_price: 2336) }
    let(:html) { Nokogiri::HTML(response.body) }

    it "hiển thị cảnh báo trước khi đóng kỳ cho system_admin" do
      get pricing_path
      expect(response.body).to include("Lưu ý khi đóng kỳ:")
      expect(response.body).to include("hoàn tất cả nhập liệu lẫn cấu trúc")
      expect(response.body).to include("toàn bộ số liệu của kỳ này sẽ bị khóa")
    end

    it "cảnh báo nhập liệu được phép sửa khi mở lại kỳ cũ" do
      get pricing_path
      %w[điện\ lực công\ tơ tổn\ hao bơm\ nước nhóm\ cấp\ bậc ngoài\ biên\ chế
         khấu\ trừ\ khác công\ cộng\ đơn\ vị phân\ bổ\ bơm\ nước].each do |term|
        expect(response.body).to include(term)
      end
    end

    it "cảnh báo cấu trúc không thể thay đổi khi mở lại kỳ cũ" do
      get pricing_path
      expect(response.body).to include("Không thể thay đổi cấu trúc")
      %w[khu\ vực đơn\ vị đầu\ mối công\ tơ\ tổng nhóm\ cấp\ bậc].each do |term|
        expect(response.body).to include(term)
      end
    end

    it "cảnh báo phải đóng hết kỳ đang mở trước khi mở lại kỳ cũ" do
      get pricing_path
      expect(response.body).to include("phải đóng hết các kỳ đang mở trước")
    end

    it "chặn vai trò không có quyền truy cập trang đơn giá" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      unit_admin = create(:user, :unit_admin, unit: unit)
      sign_in unit_admin
      get pricing_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).not_to include("Lưu ý khi đóng kỳ:")
    end
  end

  describe "access guards (chỉ system_admin)" do
    let!(:zone) { create(:zone) }
    let!(:unit) { create(:unit, zone: zone) }
    let!(:period) { create(:period, year: 2026, month: 5, closed: false, unit_price: 2336.4) }

    context "as unit_admin (kể cả đơn vị quản lý khu vực)" do
      let(:admin) { create(:user, :unit_admin, unit: unit) }
      before { sign_in admin }

      it "chặn truy cập, redirect về trang chủ kèm cảnh báo" do
        get pricing_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("errors.access_denied"))
      end
    end

    context "as commander (kể cả đơn vị quản lý khu vực)" do
      let(:commander) { create(:user, :commander, unit: unit) }
      before { sign_in commander }

      it "chặn truy cập, redirect về trang chủ kèm cảnh báo" do
        get pricing_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("errors.access_denied"))
      end
    end
  end

  describe "POST /pricing/close_period + reopen_period" do
    let!(:period) { create(:period, year: 2026, month: 5, closed: false) }

    it "đóng kỳ" do
      post close_period_pricing_path, params: { period_id: period.id }
      expect(period.reload).not_to be_open
    end

    it "mở lại kỳ" do
      period.update!(closed: true)
      post reopen_period_pricing_path, params: { period_id: period.id }
      expect(period.reload).to be_open
    end
  end
end
