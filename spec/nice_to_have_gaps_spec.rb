# Nice-to-have test gaps: N3, N4, N5, N6, N7, N8, N9, N10.
# Small tests for helpers, concerns, and edge cases already covered indirectly.
require "rails_helper"

# N3: PumpEntries optimistic locking
RSpec.describe "PumpEntries optimistic locking (N3)", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:admin) { create(:user, :system_admin) }

  before { sign_in admin }

  it "stale lock_version → flash alert + redirect" do
    r = MeterReading.joins(meter: :contact_point)
          .where(period: sample.period, contact_points: { contact_point_type: "water_pump" })
          .first
    old_lv = r.lock_version
    r.update!(reading_end: 9999)

    patch pump_entries_path, params: {
      meter_readings: { r.id.to_s => { reading_end: "8888", lock_version: old_lv } }
    }
    expect(response).to redirect_to("/")
    expect(flash[:alert]).to include("Dữ liệu đã bị thay đổi")
  end
end

# N8: PeriodHelper
RSpec.describe PeriodHelper, type: :helper do
  describe "#period_label" do
    it "kỳ có giá trị → Kỳ tháng X/Y" do
      period = build(:period, year: 2026, month: 5)
      expect(helper.period_label(period)).to eq("Kỳ tháng 5/2026")
    end

    it "nil → thông báo không có kỳ mở" do
      expect(helper.period_label(nil)).to eq(I18n.t("flash.no_open_period"))
    end
  end

  describe "#no_open_period?" do
    it "true khi không có kỳ mở" do
      helper.define_singleton_method(:current_period) { nil }
      expect(helper.no_open_period?).to be true
    end

    it "false khi có kỳ mở" do
      period = create(:period, closed: false)
      helper.define_singleton_method(:current_period) { period }
      expect(helper.no_open_period?).to be false
    end
  end
end

# N9: FlashHelper
RSpec.describe FlashHelper, type: :helper do
  describe "#flash_class" do
    it "notice → green" do
      expect(helper.flash_class("notice")).to include("green")
    end

    it "alert → red" do
      expect(helper.flash_class("alert")).to include("red")
    end

    it "warning → yellow" do
      expect(helper.flash_class("warning")).to include("yellow")
    end

    it "unknown → gray fallback" do
      expect(helper.flash_class("unknown")).to include("gray")
    end
  end
end

# N9: BreadcrumbHelper
RSpec.describe BreadcrumbHelper, type: :helper do
  describe "#page_title" do
    it "set content_for :page_title và :breadcrumb" do
      helper.page_title("Trang test")
      expect(helper.content_for(:page_title)).to eq("Trang test")
      expect(helper.content_for(:breadcrumb)).to eq("Trang test")
    end
  end
end

# N10: History range content
RSpec.describe "History range content (N10)", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:admin) { create(:user, :system_admin) }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    sign_in admin
  end

  it "range mode hiển thị summary per kỳ" do
    get history_path(mode: "range",
                     from_period_id: sample.period.id,
                     to_period_id: sample.period.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("5/2026")
  end
end
