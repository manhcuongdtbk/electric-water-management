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

  describe "cột Tổn hao / Sử dụng thực tế (TN3)" do
    let(:html) { Nokogiri::HTML(response.body) }
    let(:vi) do
      Class.new(ActionView::Base.with_empty_template_cache) { include NumberHelperVi }
        .new(ActionView::LookupContext.new([]), {}, nil)
    end

    it "luôn hiện 2 header cột" do
      sample
      get pump_entries_path
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "CHIEU-ton-hao-chua-tinh: chưa tính → loss nil (ô tổn hao để trống)" do
      sample
      get pump_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_bn1], period: sample.period)
      expect(reading.loss).to be_nil
    end

    it "có chú thích giải thích 2 cột là kết quả lần tính gần nhất" do
      sample
      get pump_entries_path
      expect(response.body).to include("kết quả lần tính gần nhất")
      expect(response.body).to include("Tính toán lại")
    end

    it "CHIEU-ton-hao-sau-tinh: sau tính → hiển thị loss và sử dụng thực tế đúng (công tơ bơm nước)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get pump_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_bn1], period: sample.period).reload
      expect(reading.loss).to be_present
      expect(response.body).to include(vi.number_to_vi(reading.loss))
      expect(response.body).to include(vi.number_to_vi(reading.usage + reading.loss))
    end

    it "CHIEU-ton-hao-vai-tro: 2 cột read-only — không thêm input vào bảng" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get pump_entries_path
      inputs = html.css("table tbody tr:first-child td input")
      # cấu trúc cũ mỗi dòng: hidden lock_version + reading_start + reading_end + manual_usage_note = 4
      expect(inputs.size).to eq(4)
    end
  end

  describe "CHIEU-ton-hao-vai-tro: 6 vai trò thấy 2 cột read-only (pump_entries)" do
    before { sample; CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    it "SA, UA-ZM, CMD-ZM, CMD thấy 2 cột (có/không data tùy phạm vi)" do
      [
        create(:user, :system_admin),                      # SA — thấy data
        create(:user, :unit_admin, unit: sample.unit_a),   # UA-ZM — thấy data bơm nước (quản lý khu vực)
        create(:user, :commander, unit: sample.unit_a),    # CMD-ZM
        create(:user, :commander, unit: sample.unit_b)     # CMD
      ].each do |u|
        sign_in u
        get pump_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
      end
    end

    it "UA (không quản lý khu vực) bảng rỗng nhưng vẫn được phép xem + thấy header" do
      sign_in create(:user, :unit_admin, unit: sample.unit_b)
      get pump_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "TECH bị chặn khỏi trang" do
      sign_in create(:user, :technician)
      get pump_entries_path
      expect(response).not_to have_http_status(:ok)
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

  describe "UI/UX improvements (#405)" do
    it "cột Tổn hao và Sử dụng thực tế có visual separation (border + background)" do
      sign_in system_admin
      get pump_entries_path
      doc = Nokogiri::HTML(response.body)
      loss_header = doc.css("th").find { |th| th.text.strip == "Tổn hao" }
      actual_header = doc.css("th").find { |th| th.text.strip == "Sử dụng thực tế" }
      expect(loss_header["class"]).to include("border-l-2").and include("bg-blue-50")
      expect(actual_header["class"]).to include("bg-blue-50")
    end
  end
end
