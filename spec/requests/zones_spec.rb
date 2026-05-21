require "rails_helper"

RSpec.describe "Zones", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:open_period) { create(:period, closed: false) }

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
    it "chặn discard zone còn unit kept" do
      zone = Zone.create!(name: "KV-X", main_meters_attributes: [{ name: "CT" }])
      create(:unit, zone: zone)
      delete zone_path(zone)
      expect(response).to redirect_to(zones_path)
      expect(flash[:alert]).to include("Phải xóa hết đơn vị")
      expect(zone.reload.discarded_at).to be_nil
    end

    it "chặn discard zone còn đầu mối trực tiếp kept (v2.3.0)" do
      zone = Zone.create!(name: "KV-Y", main_meters_attributes: [{ name: "CT" }])
      cp = ContactPoint.new(name: "Trạm bơm", contact_point_type: "water_pump", zone: zone)
      cp.meters.build(name: "Công tơ bơm")
      cp.save!
      delete zone_path(zone)
      expect(response).to redirect_to(zones_path)
      expect(flash[:alert]).to include("đầu mối")
      expect(zone.reload.discarded_at).to be_nil
    end

    it "discard zone thành công và cascade discard main_meters (v2.3.0)" do
      zone = Zone.create!(name: "KV-Z", main_meters_attributes: [{ name: "CT-Tổng" }])
      delete zone_path(zone)
      expect(response).to redirect_to(zones_path)
      expect(zone.reload.discarded_at).not_to be_nil
      expect(zone.main_meters.kept).to be_empty
    end
  end

  describe "PeriodGuard: chặn khi không có kỳ mở" do
    before { open_period.update!(closed: true) }
    let(:expected_message) {
      I18n.t("services.period_service.errors.no_open_period")
    }

    it "POST /zones bị chặn khi không có kỳ mở" do
      post zones_path, params: {
        zone: { name: "KV-gap", main_meters_attributes: [{ name: "CT" }] }
      }
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
      expect(Zone.find_by(name: "KV-gap")).to be_nil
    end

    it "GET /zones (index) vẫn được phép khi không có kỳ mở" do
      get zones_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "StructureChangeGuard: chặn khi đang mở kỳ cũ (v2.3.0)" do
    before { open_period.update!(closed: true) }
    let!(:period_jan) { create(:period, year: 2026, month: 1, closed: false) }
    let!(:period_feb) { create(:period, year: 2026, month: 2, closed: true) }
    let(:expected_message) {
      I18n.t("services.period_service.errors.structure_change_blocked_old_period")
    }

    it "GET /zones/new bị chặn khi mở kỳ cũ" do
      get new_zone_path
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "POST /zones bị chặn khi mở kỳ cũ" do
      post zones_path, params: {
        zone: { name: "KV-mới", main_meters_attributes: [{ name: "CT" }] }
      }
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
      expect(Zone.find_by(name: "KV-mới")).to be_nil
    end

    it "DELETE /zones/:id bị chặn khi mở kỳ cũ" do
      zone = Zone.create!(name: "KV-cũ", main_meters_attributes: [{ name: "CT" }])
      delete zone_path(zone)
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
      expect(zone.reload.discarded_at).to be_nil
    end
  end
end
