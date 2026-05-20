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

  describe "view permission guards" do
    let(:html) { Nokogiri::HTML(response.body) }

    context "as commander" do
      let(:commander) { create(:user, :commander, unit: sample.unit_a) }
      before do
        sample
        sign_in commander
      end

      it "hiển thị dữ liệu nhưng tất cả input đều disabled" do
        get meter_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CT-A1")
        html.css("input[type='number'], input[type='text']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
        end
      end

      it "nút Lưu toàn bộ bị disabled hoặc ẩn" do
        get meter_entries_path
        submit = html.css("input[name='commit']")
        if submit.any?
          expect(submit.first["disabled"]).to be_present,
            "Expected submit button to be disabled for commander"
        end
      end
    end

    context "as unit_admin" do
      let(:admin) { create(:user, :unit_admin, unit: sample.unit_a) }
      before do
        sample
        sign_in admin
      end

      it "input không bị disabled" do
        get meter_entries_path
        html.css("input[type='number']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_nil,
            "Expected input '#{input['name']}' to NOT be disabled for unit_admin"
        end
      end

      it "hiển thị nút Lưu toàn bộ không bị disabled" do
        get meter_entries_path
        submit = html.css("input[name='commit']")
        expect(submit).to be_present
        expect(submit.first["disabled"]).to be_nil
      end
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
