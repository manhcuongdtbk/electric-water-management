require "rails_helper"

RSpec.describe "PumpEntries", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "GET /pump_entries" do
    it "chỉ hiển thị meter công tơ bơm nước" do
      sample
      get pump_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CT-BN1")
      expect(response.body).not_to include("CT-A1")
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

      it "hiển thị dữ liệu nhưng tất cả data input đều disabled" do
        get pump_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CT-BN1")
        html.css("table input[type='number'], table input[type='text']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
        end
      end

      it "nút Lưu toàn bộ bị disabled hoặc ẩn" do
        get pump_entries_path
        submit = html.css("form[method='post'] input[name='commit']")
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
        get pump_entries_path
        html.css("input[type='number']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_nil,
            "Expected input '#{input['name']}' to NOT be disabled for unit_admin"
        end
      end

      it "hiển thị nút Lưu toàn bộ không bị disabled" do
        get pump_entries_path
        submit = html.css("input[name='commit']")
        expect(submit).to be_present
        expect(submit.first["disabled"]).to be_nil
      end
    end
  end

  describe "PATCH /pump_entries" do
    it "lưu reading_end công tơ bơm nước" do
      sample
      r = MeterReading.find_by(meter: sample.meters[:ct_bn1], period: sample.period)
      patch pump_entries_path, params: {
        meter_readings: { r.id.to_s => { reading_end: "1000", lock_version: r.lock_version } }
      }
      expect(response).to redirect_to(pump_entries_path)
      expect(r.reload.reading_end).to eq(1000)
    end

    it "lưu reading_start công tơ bơm nước" do
      sample
      r = MeterReading.find_by(meter: sample.meters[:ct_bn1], period: sample.period)
      patch pump_entries_path, params: {
        meter_readings: { r.id.to_s => { reading_start: "200", reading_end: r.reading_end.to_s, lock_version: r.lock_version } }
      }
      expect(response).to redirect_to(pump_entries_path)
      expect(r.reload.reading_start.to_f).to eq(200.0)
    end
  end
end
