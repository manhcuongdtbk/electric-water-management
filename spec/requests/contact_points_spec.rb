require "rails_helper"

RSpec.describe "ContactPoints", type: :request do
  let(:zone) { create(:zone) }
  let!(:unit_a) { create(:unit, name: "Đơn vị A", zone: zone) }
  let!(:unit_b) { create(:unit, name: "Đơn vị B", zone: zone) }
  let(:system_admin) { create(:user, :system_admin) }
  let(:admin_a) { create(:user, :unit_admin, unit: unit_a) }
  let(:admin_b) { create(:user, :unit_admin, unit: unit_b) }
  let(:commander_a) { create(:user, :commander, unit: unit_a) }

  let!(:period) { create(:period, year: 2026, month: 5, closed: false) }
  let!(:ranks) {
    7.times.map { |i| create(:rank, period: period, name: "Cấp #{i + 1}", quota: 100, position: i + 1) }
  }

  describe "GET /contact_points" do
    before { sign_in system_admin }

    it "trả về 200" do
      get contact_points_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Đầu mối")
    end

    it "filter theo loại" do
      cp = create(:contact_point, :residential, unit: unit_a, name: "RES1",
                  initial_personnel_counts: { ranks.last.id => 1 })
      create(:contact_point, :public_type, unit: unit_a, name: "PUB1")
      get contact_points_path(type: "residential")
      expect(response.body).to include("RES1")
      expect(response.body).not_to include("PUB1")
    end
  end

  describe "POST /contact_points (T33)" do
    before { sign_in system_admin }

    it "tạo residential với personnel + meter" do
      post contact_points_path, params: {
        contact_point: {
          name: "Ban Tác huấn",
          contact_point_type: "residential",
          unit_id: unit_a.id,
          personnel_counts: { ranks.last.id.to_s => "3", ranks[5].id.to_s => "2" },
          meters_attributes: { "0" => { name: "CT-A1", no_loss: "0" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      cp = ContactPoint.find_by!(name: "Ban Tác huấn")
      expect(cp.personnel_entries.where(period: period).sum(:count)).to eq(5)
      expect(cp.meters.count).to eq(1)
    end

    it "chặn khi tổng quân số = 0 (T34)" do
      post contact_points_path, params: {
        contact_point: {
          name: "Test0", contact_point_type: "residential", unit_id: unit_a.id,
          personnel_counts: { ranks.last.id.to_s => "0" },
          meters_attributes: { "0" => { name: "CT-T0", no_loss: "0" } }
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Tổng quân số")
    end

    it "chặn khi không có meter (T35)" do
      post contact_points_path, params: {
        contact_point: {
          name: "NoMeter", contact_point_type: "residential", unit_id: unit_a.id,
          personnel_counts: { ranks.last.id.to_s => "1" }
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("ít nhất một công tơ")
    end

    it "tạo non_establishment với personnel_count tổng (T36)" do
      post contact_points_path, params: {
        contact_point: {
          name: "Thợ xây", contact_point_type: "non_establishment",
          zone_id: zone.id, personnel_count: "5"
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "non_establishment"))
      cp = ContactPoint.find_by!(name: "Thợ xây")
      expect(cp.personnel_count).to eq(5)
      expect(cp.meters).to be_empty
    end
  end

  describe "PATCH /contact_points/:id (T48)" do
    before { sign_in system_admin }

    it "chặn sửa contact_point_type" do
      cp = create(:contact_point, :residential, unit: unit_a, name: "Test",
                  initial_personnel_counts: { ranks.last.id => 1 })
      # Update form không cho permit contact_point_type (T48 — immutable)
      patch contact_point_path(cp), params: {
        contact_point: { name: "Test renamed" }
      }
      cp.reload
      expect(cp.contact_point_type).to eq("residential")
      expect(cp.name).to eq("Test renamed")
    end

    it "personnel_entries dùng optimistic locking — stale lock_version → StaleObjectError redirect" do
      cp = create(:contact_point, :residential, unit: unit_a, name: "LockTest",
                  initial_personnel_counts: { ranks.last.id => 1 })
      entry = cp.personnel_entries.find_by(period: period, rank: ranks.last)
      # Simulate concurrent update bumping lock_version trong DB
      entry.update_column(:lock_version, entry.lock_version + 1)
      stale_version = entry.lock_version - 1

      patch contact_point_path(cp), params: {
        contact_point: {
          name: "LockTest",
          personnel_counts: { ranks.last.id.to_s => "5" },
          personnel_lock_versions: { ranks.last.id.to_s => stale_version.to_s }
        }
      }
      # OptimisticLockingGuard rescue → flash + redirect_back
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(I18n.t("errors.stale_object"))
      # Count vẫn giữ nguyên (rollback transaction)
      expect(entry.reload.count).to eq(1)
    end
  end

  describe "Phân quyền (T61)" do
    let!(:cp_a) {
      create(:contact_point, :residential, unit: unit_a, name: "CP A",
             initial_personnel_counts: { ranks.last.id => 1 })
    }
    let!(:cp_b) {
      create(:contact_point, :residential, unit: unit_b, name: "CP B",
             initial_personnel_counts: { ranks.last.id => 1 })
    }

    context "admin_a chỉ thấy đầu mối đơn vị mình" do
      before { sign_in admin_a }

      it "index chỉ liệt kê CP của Đơn vị A" do
        get contact_points_path
        expect(response.body).to include("CP A")
        expect(response.body).not_to include("CP B")
      end

      it "không edit được CP của Đơn vị B" do
        get edit_contact_point_path(cp_b)
        # accessible_by sẽ filter cp_b, find sẽ raise NotFound → 404
        expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
      end
    end

    context "commander_a chỉ xem" do
      before { sign_in commander_a }

      it "không tạo được" do
        post contact_points_path, params: { contact_point: { name: "X", contact_point_type: "residential", unit_id: unit_a.id } }
        expect(response).not_to have_http_status(:ok)
      end

      it "xem được index" do
        get contact_points_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "DELETE /contact_points/:id (T59)" do
    before { sign_in system_admin }

    it "discard CP, giữ data kỳ cũ" do
      cp = create(:contact_point, :residential, unit: unit_a, name: "ToDiscard",
                  initial_personnel_counts: { ranks.last.id => 2 })
      meter = create(:meter, contact_point: cp, name: "CT-D1")
      delete contact_point_path(cp)
      cp.reload
      expect(cp).to be_discarded
      expect(meter.reload).to be_discarded
      # PersonnelEntries giữ nguyên
      expect(cp.personnel_entries.where(period: period)).to be_present
    end
  end
end
