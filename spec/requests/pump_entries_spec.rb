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
  end
end
