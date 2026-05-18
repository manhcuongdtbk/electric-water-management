require "rails_helper"

RSpec.describe "Zones", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  describe "POST /zones (T27, T28)" do
    it "T27: tạo zone kèm main_meter" do
      post zones_path, params: {
        zone: { name: "Khu vực 1", main_meters_attributes: [{ name: "CT-Tổng-KV1" }] }
      }
      expect(response).to redirect_to(zones_path)
      zone = Zone.find_by!(name: "Khu vực 1")
      expect(zone.main_meters.count).to eq(1)
      expect(zone.main_meters.first.name).to eq("CT-Tổng-KV1")
    end

    it "T28: chặn tạo zone thiếu main_meter" do
      post zones_path, params: { zone: { name: "Khu vực 2" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("ít nhất một công tơ tổng")
    end
  end

  describe "PATCH /zones/:id/reassign_manager (T31)" do
    let!(:zone) {
      Zone.create!(name: "KV-Test", main_meters_attributes: [{ name: "CT" }])
    }
    let!(:unit_a) { create(:unit, zone: zone) }
    let!(:unit_b) { create(:unit, zone: zone) }

    it "đổi manager unit" do
      expect(zone.reload.manager_unit_id).to eq(unit_a.id)
      patch reassign_manager_zone_path(zone), params: { manager_unit_id: unit_b.id }
      expect(zone.reload.manager_unit_id).to eq(unit_b.id)
    end

    it "không cho gán unit thuộc zone khác" do
      other_zone = Zone.create!(name: "KV-Other", main_meters_attributes: [{ name: "CT2" }])
      other_unit = create(:unit, zone: other_zone)
      patch reassign_manager_zone_path(zone), params: { manager_unit_id: other_unit.id }
      expect(zone.reload.manager_unit_id).not_to eq(other_unit.id)
    end
  end

  describe "DELETE /zones/:id (T40)" do
    it "chặn xóa zone còn unit kept" do
      zone = Zone.create!(name: "KV-X", main_meters_attributes: [{ name: "CT" }])
      create(:unit, zone: zone)
      delete zone_path(zone)
      expect(response).to redirect_to(zones_path)
      expect(flash[:alert]).to include("Phải xóa hết đơn vị")
    end
  end
end
