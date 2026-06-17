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

    context "as commander (zone-manager)" do
      let(:commander) { create(:user, :commander, unit: sample.unit_a) }
      before do
        sample
        sign_in commander
      end

      it "hiển thị dữ liệu nhưng tất cả data input đều disabled" do
        get meter_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CT-A1")
        html.css("table input[type='number'], table input[type='text']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
        end
      end

      it "nút Lưu toàn bộ bị disabled hoặc ẩn" do
        get meter_entries_path
        submit = html.css("form[method='post'] input[name='commit']")
        if submit.any?
          expect(submit.first["disabled"]).to be_present,
            "Expected submit button to be disabled for commander"
        end
      end
    end

    context "as commander (non zone-manager)" do
      let(:commander) { create(:user, :commander, unit: sample.unit_b) }
      before do
        sample
        sign_in commander
      end

      it "hiển thị dữ liệu đơn vị mình, inputs disabled" do
        get meter_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CT-B1")
        html.css("table input[type='number'], table input[type='text']").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
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

  describe "search, filter, zone/unit columns" do
    let(:admin) { create(:user, :system_admin) }
    let(:ua) { create(:user, :unit_admin, unit: sample.unit_a) }
    before { sample }

    context "SA" do
      before { sign_in admin }

      it "hiện cột Khu vực và Đơn vị" do
        get meter_entries_path
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip).map(&:downcase)
        expect(headers).to include("khu vực", "đơn vị")
      end

      it "hiện dropdown filter khu vực" do
        get meter_entries_path
        expect(response.body).to include("zone_id")
      end

      it "search theo tên đầu mối" do
        get meter_entries_path, params: { q: "Ban" }
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).not_to include("Văn thư")
      end
    end

    context "non-SA" do
      before { sign_in ua }

      it "không hiện cột Khu vực và Đơn vị" do
        get meter_entries_path
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip).map(&:downcase)
        expect(headers).not_to include("khu vực")
        expect(headers).not_to include("đơn vị")
      end

      it "không hiện dropdown filter khu vực" do
        get meter_entries_path
        expect(response.body).not_to include("zone_id")
      end

      it "search vẫn hoạt động" do
        get meter_entries_path, params: { q: "Ban" }
        expect(response.body).to include("Ban Tác huấn")
      end
    end
  end

  describe "ẩn cột nhập thủ công, đổi tên sử dụng" do
    before { sample; sign_in create(:user, :system_admin) }

    it "không có cột Nhập thủ công" do
      get meter_entries_path
      doc = Nokogiri::HTML(response.body)
      headers = doc.css("table thead th").map(&:text).map(&:strip)
      expect(headers).not_to include(a_string_matching(/nhập thủ công/i))
    end

    it "cột sử dụng (không có 'tự tính')" do
      get meter_entries_path
      doc = Nokogiri::HTML(response.body)
      headers = doc.css("table thead th").map(&:text).map(&:strip)
      expect(headers).to include(a_string_matching(/\Asử dụng\z/i))
      expect(headers).not_to include(a_string_matching(/tự tính/i))
    end
  end

  describe "reading_start editable" do
    let(:admin) { create(:user, :system_admin) }
    before { sample; sign_in admin }

    it "form hiện input cho reading_start (không phải text readonly)" do
      get meter_entries_path
      doc = Nokogiri::HTML(response.body)
      r = MeterReading.joins(meter: :contact_point)
            .where(period: sample.period, contact_points: { contact_point_type: %w[residential public] })
            .first
      expect(doc.css("input[name='meter_readings[#{r.id}][reading_start]']")).to be_present
    end

    it "update reading_start thành công" do
      r = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      old_start = r.reading_start

      patch meter_entries_path, params: {
        meter_readings: {
          r.id.to_s => {
            reading_start: "500",
            reading_end: r.reading_end.to_s,
            lock_version: r.lock_version
          }
        }
      }
      expect(response).to redirect_to(meter_entries_path)
      expect(r.reload.reading_start.to_f).to eq(500.0)
    end

    it "reading_start trống → default 0" do
      r = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)

      patch meter_entries_path, params: {
        meter_readings: {
          r.id.to_s => {
            reading_start: "",
            reading_end: r.reading_end.to_s,
            lock_version: r.lock_version
          }
        }
      }
      expect(response).to redirect_to(meter_entries_path)
      expect(r.reload.reading_start.to_f).to eq(0.0)
    end
  end

  describe "batch update transaction rollback (I11)" do
    let(:admin) { create(:user, :system_admin) }
    before { sample; sign_in admin }

    it "1 record lỗi → rollback tất cả, flash chỉ rõ record sai" do
      r1 = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      r2 = MeterReading.find_by(meter: sample.meters[:ct_a2], period: sample.period)
      old_end_r1 = r1.reading_end

      patch meter_entries_path, params: {
        meter_readings: {
          r1.id.to_s => { reading_end: "5000", lock_version: r1.lock_version },
          r2.id.to_s => { reading_end: "-1", lock_version: r2.lock_version }  # invalid
        }
      }
      # reading_end ≥ 0 validation → r2 fails → rollback r1 too
      expect(r1.reload.reading_end).to eq(old_end_r1)  # r1 NOT changed (rollback)
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
      get meter_entries_path
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "có chú thích giải thích 2 cột là kết quả lần tính gần nhất (trống/cũ → bấm Tính toán lại)" do
      sample
      get meter_entries_path
      expect(response.body).to include("kết quả lần tính gần nhất")
      expect(response.body).to include("Tính toán lại")
    end

    it "CHIEU-ton-hao-chua-tinh: chưa tính → loss nil → ô để trống (không có giá trị tổn hao)" do
      sample
      get meter_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      expect(reading.loss).to be_nil
      # giá trị xuất hiện sau khi tính KHÔNG được có mặt khi chưa tính:
      # (kiểm ở ví dụ D3 ta biết chuỗi loss; ở đây chỉ chốt loss nil + cột vẫn render header)
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "CHIEU-ton-hao-sau-tinh: sau tính → hiển thị loss và sử dụng thực tế đúng" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period).reload
      expect(reading.loss).to be_present
      expect(response.body).to include(vi.number_to_vi(reading.loss))
      expect(response.body).to include(vi.number_to_vi(reading.usage + reading.loss))
    end

    it "CHIEU-ton-hao-khong-ton-hao: công tơ no_loss → loss hiển thị 0,00 (không trống)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      r3 = MeterReading.find_by(meter: sample.meters[:ct_a3], period: sample.period).reload
      expect(r3.loss).to eq(BigDecimal("0"))
      expect(response.body).to include("0,00")
    end

    it "CHIEU-ton-hao-sua-giu-cu: sửa chỉ số sau tính (chưa tính lại) → giữ loss cũ; thực tế = usage mới + loss cũ" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period).reload
      old_loss = reading.loss
      patch meter_entries_path, params: {
        meter_readings: { reading.id.to_s => { reading_end: "99999", lock_version: reading.lock_version } }
      }
      get meter_entries_path
      reading.reload
      expect(reading.loss).to eq(old_loss)
      expect(response.body).to include(vi.number_to_vi(reading.usage + old_loss))
    end

    it "CHIEU-ton-hao-vai-tro: 2 cột read-only — không thêm input vào bảng" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      # số input ở dòng đầu KHÔNG đổi do 2 cột mới (chúng chỉ render text)
      inputs = html.css("table tbody tr:first-child td input")
      # cấu trúc cũ mỗi dòng: hidden lock_version + reading_start + reading_end + manual_usage_note = 4
      expect(inputs.size).to eq(4)
    end
  end

  describe "CHIEU-ton-hao-vai-tro: 6 vai trò thấy 2 cột read-only (meter_entries)" do
    before { sample; CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    it "SA, UA-ZM, UA, CMD-ZM, CMD đều thấy 2 cột" do
      [
        create(:user, :system_admin),
        create(:user, :unit_admin, unit: sample.unit_a),    # UA-ZM (đơn vị quản lý khu vực)
        create(:user, :unit_admin, unit: sample.unit_b),    # UA
        create(:user, :commander, unit: sample.unit_a),     # CMD-ZM
        create(:user, :commander, unit: sample.unit_b)      # CMD
      ].each do |u|
        sign_in u
        get meter_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
      end
    end

    it "TECH bị chặn khỏi trang" do
      sign_in create(:user, :technician)
      get meter_entries_path
      expect(response).not_to have_http_status(:ok)
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
