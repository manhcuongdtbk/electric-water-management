require "rails_helper"

RSpec.describe "Period indicator partial", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "displays period label with open badge on all pages" do
    let!(:period) { create(:period, month: 5, year: 2026, closed: false) }

    shared_examples "period indicator with open badge" do
      it "shows period label and open badge" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Kỳ tháng 5/2026")
        expect(response.body).to include("Đang mở")
      end
    end

    context "zones index" do
      before { get zones_path }
      include_examples "period indicator with open badge"
    end

    context "units index" do
      before { get units_path }
      include_examples "period indicator with open badge"
    end

    context "blocks index" do
      before { get blocks_path }
      include_examples "period indicator with open badge"
    end

    context "groups index" do
      before { get groups_path }
      include_examples "period indicator with open badge"
    end

    context "contact_points index" do
      before { get contact_points_path }
      include_examples "period indicator with open badge"
    end

    context "ranks index" do
      before { get ranks_path }
      include_examples "period indicator with open badge"
    end

    context "pump_allocations index" do
      before { get pump_allocations_path }
      include_examples "period indicator with open badge"
    end

    context "unit_config show" do
      let!(:unit) { create(:unit) }
      before { get unit_config_path(unit_id: unit.id) }
      include_examples "period indicator with open badge"
    end

    context "pump_entries show" do
      before { get pump_entries_path }
      include_examples "period indicator with open badge"
    end

    context "meter_entries show" do
      before { get meter_entries_path }
      include_examples "period indicator with open badge"
    end

    context "electricity_supply show" do
      before { get electricity_supply_path }
      include_examples "period indicator with open badge"
    end
  end

  describe "displays warning banner when no period exists" do
    shared_examples "no period warning banner" do
      it "shows warning message" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Chưa có kỳ nào trong hệ thống")
      end
    end

    context "zones index" do
      before { get zones_path }
      include_examples "no period warning banner"
    end

    context "units index" do
      before { get units_path }
      include_examples "no period warning banner"
    end

    context "blocks index" do
      before { get blocks_path }
      include_examples "no period warning banner"
    end

    context "groups index" do
      before { get groups_path }
      include_examples "no period warning banner"
    end

    context "contact_points index" do
      before { get contact_points_path }
      include_examples "no period warning banner"
    end

    context "ranks index" do
      before { get ranks_path }
      include_examples "no period warning banner"
    end

    context "pump_allocations index" do
      before { get pump_allocations_path }
      include_examples "no period warning banner"
    end

    context "unit_config show" do
      let!(:unit) { create(:unit) }
      let!(:unit_admin) { create(:user, :unit_admin, unit: unit) }
      before do
        sign_in unit_admin
        get unit_config_path
      end
      include_examples "no period warning banner"
    end

    context "pump_entries show" do
      before { get pump_entries_path }
      include_examples "no period warning banner"
    end

    context "meter_entries show" do
      before { get meter_entries_path }
      include_examples "no period warning banner"
    end

    context "electricity_supply show" do
      before { get electricity_supply_path }
      include_examples "no period warning banner"
    end
  end

  describe "displays closed badge when viewing closed period" do
    let!(:closed_period) { create(:period, month: 5, year: 2026, closed: true) }

    it "ranks index shows closed badge (falls back to latest period)" do
      get ranks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kỳ tháng 5/2026")
      expect(response.body).to include("Đã đóng")
    end
  end

  describe "unit_config shows unit-specific messages when user has no unit" do
    it "system_admin sees unit selection prompt instead of period indicator" do
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vui lòng chọn đơn vị bên dưới")
    end

    it "unit_admin without unit sees assignment warning instead of period indicator" do
      unit_admin = create(:user, :unit_admin)
      unit_admin.update_column(:unit_id, nil)
      sign_in unit_admin
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bạn chưa được gán đơn vị nào")
    end
  end
end
