require "rails_helper"

RSpec.describe "ElectricitySupply", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "GET /electricity_supply" do
    it "T68: nhập số sử dụng công tơ tổng" do
      sample
      get electricity_supply_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CT-Tổng-KV1")
    end
  end

  describe "PATCH /electricity_supply (T68)" do
    it "lưu usage main_meter" do
      sample
      reading = sample.main_meter_reading
      patch electricity_supply_path, params: {
        main_meter_readings: { reading.id.to_s => { usage: "3000", lock_version: reading.lock_version } }
      }
      expect(response).to redirect_to(electricity_supply_path)
      expect(reading.reload.usage).to eq(3000)
    end
  end

  describe "T70: không có kỳ đang mở" do
    it "show vẫn render, banner cảnh báo" do
      sample.period.update!(closed: true)
      get electricity_supply_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Không có kỳ đang mở")
    end
  end
end
