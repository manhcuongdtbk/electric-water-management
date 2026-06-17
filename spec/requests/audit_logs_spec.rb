require "rails_helper"

RSpec.describe "AuditLogs", type: :request do
  let(:technician) { create(:user, role: :technician) }
  let(:system_admin) { create(:user, :system_admin) }
  let!(:open_period) { create(:period, closed: false) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:unit_admin) { create(:user, :unit_admin, unit: unit) }

  describe "T95: phân quyền truy cập" do
    it "technician truy cập được" do
      sign_in technician
      get audit_logs_path
      expect(response).to have_http_status(:ok)
    end

    it "system_admin truy cập được" do
      sign_in system_admin
      get audit_logs_path
      expect(response).to have_http_status(:ok)
    end

    it "unit_admin bị chặn → redirect root" do
      sign_in unit_admin
      get audit_logs_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "T94: tạo / sửa / xóa Zone ghi version" do
    before { sign_in system_admin }

    it "tạo Zone → có version event=create" do
      expect {
        post zones_path, params: {
          zone: { name: "Z Audit Create", main_meters_attributes: [{ name: "MM" }] }
        }
      }.to change { PaperTrail::Version.where(item_type: "Zone", event: "create").count }.by(1)
    end

    it "sửa Zone → có version event=update với object_changes" do
      zone_to_update = create(:zone, name: "Z Old")
      expect {
        patch zone_path(zone_to_update), params: { zone: { name: "Z New" } }
      }.to change { PaperTrail::Version.where(item_type: "Zone", item_id: zone_to_update.id, event: "update").count }.by_at_least(1)
      v = PaperTrail::Version.where(item_type: "Zone", item_id: zone_to_update.id, event: "update").order(:created_at).last
      expect(v.object_changes).to be_present
      changes = YAML.unsafe_load(v.object_changes)
      expect(changes["name"]).to eq(["Z Old", "Z New"])
    end
  end

  describe "filters" do
    before do
      sign_in system_admin
      PaperTrail.request(whodunnit: system_admin.id) do
        @z = create(:zone, name: "Z Filter")
        @u = create(:unit, zone: @z, name: "U Filter")
      end
    end

    it "filter theo item_type" do
      get audit_logs_path, params: { item_type: "Unit" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Đơn vị")
    end

    it "filter theo event" do
      get audit_logs_path, params: { event: "create" }
      expect(response).to have_http_status(:ok)
    end

    it "filter theo whodunnit" do
      get audit_logs_path, params: { whodunnit: system_admin.id.to_s }
      expect(response).to have_http_status(:ok)
    end

    it "filter theo from/to date" do
      get audit_logs_path, params: { from: Date.current.strftime("%Y-%m-%d"),
                                       to: Date.current.strftime("%Y-%m-%d") }
      expect(response).to have_http_status(:ok)
    end

    it "filter theo per_page" do
      get audit_logs_path, params: { per_page: 10 }
      expect(response).to have_http_status(:ok)
    end

    it "ignore invalid event" do
      get audit_logs_path, params: { event: "; DROP TABLE users; --" }
      expect(response).to have_http_status(:ok)
    end

    it "ignore invalid item_type không trong whitelist" do
      get audit_logs_path, params: { item_type: "Object" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /audit_logs/:id (show)" do
    let(:zone_to_update) { create(:zone, name: "Z Show Old") }

    before do
      sign_in system_admin
      PaperTrail.request(whodunnit: system_admin.id) { zone_to_update.update!(name: "Z Show New") }
    end

    it "render diff before/after" do
      version = PaperTrail::Version.where(item_type: "Zone", item_id: zone_to_update.id, event: "update").last
      get audit_log_path(version)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Z Show Old")
      expect(response.body).to include("Z Show New")
    end

    it "show with nil object_changes (create event)" do
      version = PaperTrail::Version.where(item_type: "Zone", event: "create").last
      get audit_log_path(version)
      expect(response).to have_http_status(:ok)
    end

    it "show with invalid YAML in object gracefully handles" do
      version = PaperTrail::Version.where(item_type: "Zone", event: "update").last
      version.update_column(:object, "invalid: yaml: [broken")
      get audit_log_path(version)
      expect(response).to have_http_status(:ok)
    end

    it "unit_admin bị chặn show" do
      version = PaperTrail::Version.where(item_type: "Zone", item_id: zone_to_update.id).last
      sign_out system_admin
      sign_in unit_admin
      get audit_log_path(version)
      expect(response).to redirect_to(root_path)
    end
  end
end
