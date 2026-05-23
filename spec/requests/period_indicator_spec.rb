require "rails_helper"

RSpec.describe "Period info in topbar", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "topbar hiện kỳ đang mở với badge" do
    let!(:period) { create(:period, month: 5, year: 2026, closed: false) }

    shared_examples "topbar period badge" do
      it "hiện tên kỳ và badge Đang mở" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Kỳ tháng 5/2026")
        expect(response.body).to include(I18n.t("common.badges.open"))
      end
    end

    context("zones")          { before { get zones_path };          include_examples "topbar period badge" }
    context("units")          { before { get units_path };          include_examples "topbar period badge" }
    context("blocks")         { before { get blocks_path };         include_examples "topbar period badge" }
    context("groups")         { before { get groups_path };         include_examples "topbar period badge" }
    context("contact_points") { before { get contact_points_path }; include_examples "topbar period badge" }
    context("ranks")          { before { get ranks_path };          include_examples "topbar period badge" }
    context("pump_allocations") { before { get pump_allocations_path }; include_examples "topbar period badge" }
    context("meter_entries")  { before { get meter_entries_path };  include_examples "topbar period badge" }
    context("pump_entries")   { before { get pump_entries_path };   include_examples "topbar period badge" }
    context("electricity_supply") { before { get electricity_supply_path }; include_examples "topbar period badge" }
  end

  describe "topbar hiện cảnh báo khi không có kỳ đang mở" do
    it "hiện thông báo không có kỳ" do
      get zones_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Không có kỳ đang mở")
    end
  end
end
