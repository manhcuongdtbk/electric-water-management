require "rails_helper"

RSpec.describe "MeterEntries", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "GET /meter_entries" do
    it "trả về 200" do
      sample
      get meter_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CT-A1")
    end

    it "không bao gồm meter công tơ bơm nước (đó là /pump_entries)" do
      sample
      get meter_entries_path
      expect(response.body).not_to include("CT-BN1")
    end
  end

  describe "PATCH /meter_entries (T67)" do
    it "lưu reading_end nhiều meter cùng lúc" do
      sample
      r1 = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      patch meter_entries_path, params: {
        meter_readings: {
          r1.id.to_s => { reading_end: "1300", lock_version: r1.lock_version }
        }
      }
      expect(response).to redirect_to(meter_entries_path)
      expect(r1.reload.reading_end).to eq(1300)
    end

    it "T58: chấp nhận manual_usage khi cuối kỳ < đầu kỳ (thay công tơ)" do
      sample
      r1 = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      patch meter_entries_path, params: {
        meter_readings: {
          r1.id.to_s => {
            reading_end: "500", manual_usage: "200",
            manual_usage_note: "Thay công tơ mới", lock_version: r1.lock_version
          }
        }
      }
      expect(response).to redirect_to(meter_entries_path)
      r1.reload
      expect(r1.usage).to eq(200)
      expect(r1.manual_usage_note).to eq("Thay công tơ mới")
    end
  end

  describe "T74: optimistic locking" do
    it "raise StaleObjectError khi lock_version cũ → flash alert + redirect" do
      sample
      r1 = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      old_lv = r1.lock_version
      r1.update!(reading_end: 9999)  # bump lock_version

      patch meter_entries_path, params: {
        meter_readings: { r1.id.to_s => { reading_end: "8888", lock_version: old_lv } }
      }
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to include("Dữ liệu đã bị thay đổi")
    end
  end
end
