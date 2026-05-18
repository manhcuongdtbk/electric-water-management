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
