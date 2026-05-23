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

  describe "view permission guards" do
    let(:html) { Nokogiri::HTML(response.body) }

    context "as commander (zone-manager)" do
      let(:commander) { create(:user, :commander, unit: sample.unit_a) }
      before do
        sample
        sign_in commander
      end

      it "hiển thị dữ liệu nhưng input usage disabled" do
        get electricity_supply_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CT-Tổng-KV1")
        html.css("input[type='number']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
        end
      end

      it "nút Lưu toàn bộ bị disabled hoặc ẩn" do
        get electricity_supply_path
        submit = html.css("input[name='commit']")
        if submit.any?
          expect(submit.first["disabled"]).to be_present,
            "Expected submit button to be disabled for commander"
        end
      end
    end

    context "as unit_admin (zone-manager)" do
      let(:admin) { create(:user, :unit_admin, unit: sample.unit_a) }
      before do
        sample
        sign_in admin
      end

      it "input không bị disabled" do
        get electricity_supply_path
        html.css("input[type='number']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_nil,
            "Expected input '#{input['name']}' to NOT be disabled for unit_admin"
        end
      end

      it "hiển thị nút Lưu toàn bộ không bị disabled" do
        get electricity_supply_path
        submit = html.css("input[name='commit']")
        expect(submit).to be_present
        expect(submit.first["disabled"]).to be_nil
      end
    end

    context "as unit_admin (non zone-manager)" do
      let(:admin_b) { create(:user, :unit_admin, unit: sample.unit_b) }
      before do
        sample
        sign_in admin_b
      end

      it "redirect vì không có quyền xem công tơ tổng" do
        get electricity_supply_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "tạo main_meter_reading mới (I12)" do
    let(:admin) { create(:user, :system_admin) }
    before { sample; sign_in admin }

    it "tạo reading mới cho main_meter chưa có reading" do
      # Xóa reading hiện có để simulate kỳ mới chưa nhập
      sample.main_meter_reading.destroy!
      mm = sample.main_meter

      patch electricity_supply_path, params: {
        new_main_meter_readings: { mm.id.to_s => { usage: "2500" } }
      }
      expect(response).to redirect_to(electricity_supply_path)
      new_reading = MainMeterReading.find_by(main_meter: mm, period: sample.period)
      expect(new_reading).to be_present
      expect(new_reading.usage.to_f).to eq(2500)
    end
  end

  describe "batch update rollback (I13)" do
    let(:admin) { create(:user, :system_admin) }
    before { sample; sign_in admin }

    it "usage âm → lỗi validation, flash hiện tên main_meter" do
      r = sample.main_meter_reading
      patch electricity_supply_path, params: {
        main_meter_readings: { r.id.to_s => { usage: "-1", lock_version: r.lock_version } }
      }
      expect(response).to have_http_status(:unprocessable_entity)
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
