require "rails_helper"

RSpec.describe "Topbar", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "enterprise dark header" do
    let!(:period) { create(:period, month: 5, year: 2026, closed: false) }

    it "dùng bg-blue-900 (dark header)" do
      get zones_path
      expect(response.body).to include("bg-blue-900")
    end

    it "hiện tên hệ thống (trắng)" do
      get zones_path
      expect(response.body).to include(I18n.t("application.name"))
    end

    it "hiện tên kỳ và trạng thái Đang mở" do
      get zones_path
      expect(response.body).to include("Kỳ tháng 5/2026")
      expect(response.body).to include(I18n.t("common.badges.open"))
    end

    it "Đang mở dùng text-green-300 (không phải badge lồng badge)" do
      get zones_path
      expect(response.body).to include("text-green-300")
      expect(response.body).not_to include("bg-green-100")
    end

    it "hiện user name và role" do
      get zones_path
      expect(response.body).to include(system_admin.display_name)
      expect(response.body).to include(I18n.t("activerecord.attributes.user.roles.system_admin"))
    end

    it "Đổi mật khẩu dùng text-blue-200 (không underline)" do
      get zones_path
      expect(response.body).to include("text-blue-200")
      expect(response.body).to include(I18n.t("common.actions.change_password"))
    end

    it "Đăng xuất dùng text-red-300" do
      get zones_path
      expect(response.body).to include("text-red-300")
      expect(response.body).to include(I18n.t("common.actions.logout"))
    end
  end

  describe "topbar kỳ đang mở — hiện trên mọi trang" do
    let!(:period) { create(:period, month: 5, year: 2026, closed: false) }

    shared_examples "topbar period info" do
      it "hiện tên kỳ và trạng thái" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Kỳ tháng 5/2026")
        expect(response.body).to include(I18n.t("common.badges.open"))
      end
    end

    context("zones")          { before { get zones_path };          include_examples "topbar period info" }
    context("units")          { before { get units_path };          include_examples "topbar period info" }
    context("blocks")         { before { get blocks_path };         include_examples "topbar period info" }
    context("groups")         { before { get groups_path };         include_examples "topbar period info" }
    context("contact_points") { before { get contact_points_path }; include_examples "topbar period info" }
    context("ranks")          { before { get ranks_path };          include_examples "topbar period info" }
    context("pump_allocations") { before { get pump_allocations_path }; include_examples "topbar period info" }
    context("meter_entries")  { before { get meter_entries_path };  include_examples "topbar period info" }
    context("pump_entries")   { before { get pump_entries_path };   include_examples "topbar period info" }
    context("electricity_supply") { before { get electricity_supply_path }; include_examples "topbar period info" }
  end

  describe "topbar không có kỳ đang mở" do
    it "hiện cảnh báo text-yellow-300" do
      get zones_path
      expect(response.body).to include("Không có kỳ đang mở")
      expect(response.body).to include("text-yellow-300")
    end
  end
end
