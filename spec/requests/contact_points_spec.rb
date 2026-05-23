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

    context "SA filter theo zone (bao gồm zone trực tiếp + qua unit)" do
      let!(:zone2) { create(:zone, name: "Khu vực 2") }
      let!(:unit_z2) { create(:unit, name: "Đơn vị Z2", zone: zone2) }

      let!(:cp_unit_a) do
        create(:contact_point, :residential, unit: unit_a, name: "CP Đơn vị A",
               initial_personnel_counts: { ranks.last.id => 1 })
      end
      let!(:cp_unit_z2) do
        create(:contact_point, :residential, unit: unit_z2, name: "CP Đơn vị Z2",
               initial_personnel_counts: { ranks.last.id => 1 })
      end
      let!(:cp_zone_direct) do
        create(:contact_point, :zone_residential, zone: zone, name: "CP Khu vực trực tiếp",
               initial_personnel_counts: { ranks.last.id => 1 })
      end

      it "chọn zone → hiện đầu mối thuộc zone trực tiếp + đầu mối đơn vị trong zone" do
        get contact_points_path(zone_id: zone.id)
        expect(response.body).to include("CP Đơn vị A", "CP Khu vực trực tiếp")
        expect(response.body).not_to include("CP Đơn vị Z2")
      end

      it "chọn unit → chỉ hiện đầu mối thuộc unit đó" do
        get contact_points_path(unit_id: unit_a.id)
        expect(response.body).to include("CP Đơn vị A")
        expect(response.body).not_to include("CP Đơn vị Z2", "CP Khu vực trực tiếp")
      end

      it "không chọn filter → hiện tất cả" do
        get contact_points_path
        expect(response.body).to include("CP Đơn vị A", "CP Đơn vị Z2", "CP Khu vực trực tiếp")
      end
    end

    it "tìm kiếm sanitize ký tự ILIKE wildcard" do
      create(:contact_point, :public_type, unit: unit_a, name: "Kho 50%")
      create(:contact_point, :public_type, unit: unit_a, name: "Kho 500 tấn")
      get contact_points_path, params: { q: "50%" }
      expect(response.body).to include("Kho 50%")
      expect(response.body).not_to include("500 tấn")
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

  describe "assignment_mode xử lý đúng khi cả zone_id và unit_id có trong params" do
    before { sign_in system_admin }

    it "assignment_mode=unit → giữ unit_id, xoá zone_id" do
      post contact_points_path, params: {
        assignment_mode: "unit",
        contact_point: {
          name: "Nhà ăn", contact_point_type: "public",
          unit_id: unit_a.id, zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-test", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by!(name: "Nhà ăn")
      expect(cp.unit_id).to eq(unit_a.id)
      expect(cp.zone_id).to be_nil
    end

    it "assignment_mode=zone → giữ zone_id, xoá unit_id" do
      post contact_points_path, params: {
        assignment_mode: "zone",
        contact_point: {
          name: "Đèn đường", contact_point_type: "public",
          unit_id: unit_a.id, zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-dd", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by!(name: "Đèn đường")
      expect(cp.zone_id).to eq(zone.id)
      expect(cp.unit_id).to be_nil
    end

    it "UA-ZM chọn đơn vị → CP thuộc đơn vị, không thuộc khu vực" do
      ua_zm = create(:user, :unit_admin, unit: unit_a)
      sign_in ua_zm
      post contact_points_path, params: {
        assignment_mode: "unit",
        contact_point: {
          name: "Nhà ăn UA-ZM", contact_point_type: "public",
          unit_id: unit_a.id, zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-na", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by!(name: "Nhà ăn UA-ZM")
      expect(cp.unit_id).to eq(unit_a.id)
      expect(cp.zone_id).to be_nil
    end

    it "UA-ZM chọn khu vực → CP thuộc khu vực, không thuộc đơn vị" do
      ua_zm = create(:user, :unit_admin, unit: unit_a)
      sign_in ua_zm
      post contact_points_path, params: {
        assignment_mode: "zone",
        contact_point: {
          name: "Đèn đường UA-ZM", contact_point_type: "public",
          unit_id: unit_a.id, zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-dd-zm", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by!(name: "Đèn đường UA-ZM")
      expect(cp.zone_id).to eq(zone.id)
      expect(cp.unit_id).to be_nil
    end

    it "không có assignment_mode, chỉ zone_id → zone-level (backward compat)" do
      post contact_points_path, params: {
        contact_point: {
          name: "Cổng gác", contact_point_type: "public",
          zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-cg", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by!(name: "Cổng gác")
      expect(cp.zone_id).to eq(zone.id)
      expect(cp.unit_id).to be_nil
    end
  end

  describe "UA-ZM tạo zone-level CP (không qua accessible_by Zone)" do
    let(:ua_zm) { create(:user, :unit_admin, unit: unit_a) }
    before { sign_in ua_zm }

    it "tạo residential thuộc khu vực" do
      post contact_points_path, params: {
        contact_point: {
          name: "Chỉ huy khu vực", contact_point_type: "residential",
          zone_id: zone.id,
          personnel_counts: { ranks.last.id.to_s => "1" },
          meters_attributes: { "0" => { name: "CT-KV", no_loss: "0" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      cp = ContactPoint.find_by!(name: "Chỉ huy khu vực")
      expect(cp.zone_id).to eq(zone.id)
      expect(cp.unit_id).to be_nil
    end

    it "tạo water_pump thuộc khu vực" do
      post contact_points_path, params: {
        contact_point: {
          name: "Trạm bơm test", contact_point_type: "water_pump",
          zone_id: zone.id,
          meters_attributes: { "0" => { name: "CT-BN-test", no_loss: "0" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "water_pump"))
      cp = ContactPoint.find_by!(name: "Trạm bơm test")
      expect(cp.zone_id).to eq(zone.id)
    end

    it "tạo non_establishment thuộc khu vực" do
      post contact_points_path, params: {
        contact_point: {
          name: "Thợ điện", contact_point_type: "non_establishment",
          zone_id: zone.id, personnel_count: "3"
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "non_establishment"))
      cp = ContactPoint.find_by!(name: "Thợ điện")
      expect(cp.zone_id).to eq(zone.id)
      expect(cp.personnel_count).to eq(3)
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

  describe "view permission guards" do
    let(:html) { Nokogiri::HTML(response.body) }
    let!(:cp_a) {
      create(:contact_point, :residential, unit: unit_a, name: "CP A",
             initial_personnel_counts: { ranks.last.id => 1 })
    }
    let!(:cp_b) {
      create(:contact_point, :residential, unit: unit_b, name: "CP B",
             initial_personnel_counts: { ranks.last.id => 1 })
    }
    let(:commander_b) { create(:user, :commander, unit: unit_b) }

    context "as commander (non zone-manager)" do
      before { sign_in commander_b }

      it "không hiển thị nút Thêm đầu mối" do
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(new_contact_point_path)
      end

      it "không hiển thị link Sửa và nút Xóa cho từng đầu mối" do
        get contact_points_path
        expect(response.body).to include("CP B")
        expect(response.body).not_to include(edit_contact_point_path(cp_b))
        html.css("form[action='#{contact_point_path(cp_b)}']").each do |form|
          expect(form.css("input[name='_method'][value='delete']")).to be_empty
        end
      end

      it "dropdown loại chỉ hiển thị Sinh hoạt và Công cộng" do
        get contact_points_path
        html = Nokogiri::HTML(response.body)
        type_options = html.css("select#type option").map { |o| o["value"] }.compact
        expect(type_options).not_to include("water_pump")
        expect(type_options).not_to include("non_establishment")
      end
    end

    context "as commander (zone-manager)" do
      before { sign_in commander_a }

      it "dropdown loại hiển thị đủ 4 loại đầu mối" do
        get contact_points_path
        html = Nokogiri::HTML(response.body)
        type_options = html.css("select#type option").map { |o| o["value"] }.compact
        expect(type_options).to include("water_pump")
        expect(type_options).to include("non_establishment")
      end

      it "vẫn không hiển thị nút Thêm đầu mối" do
        get contact_points_path
        expect(response.body).not_to include(new_contact_point_path)
      end
    end

    context "as unit_admin (zone-manager)" do
      before { sign_in admin_a }

      it "hiển thị nút Thêm đầu mối" do
        get contact_points_path
        expect(response.body).to include(new_contact_point_path)
      end

      it "hiển thị link Sửa cho đầu mối của mình" do
        get contact_points_path
        expect(response.body).to include(edit_contact_point_path(cp_a))
      end

      it "dropdown loại hiển thị đủ 4 loại đầu mối" do
        get contact_points_path
        html = Nokogiri::HTML(response.body)
        type_options = html.css("select#type option").map { |o| o["value"] }.compact
        expect(type_options).to include("water_pump")
        expect(type_options).to include("non_establishment")
      end
    end

    context "as unit_admin (non zone-manager)" do
      before { sign_in admin_b }

      it "dropdown loại chỉ hiển thị Sinh hoạt và Công cộng" do
        get contact_points_path
        html = Nokogiri::HTML(response.body)
        type_options = html.css("select#type option").map { |o| o["value"] }.compact
        expect(type_options).not_to include("water_pump")
        expect(type_options).not_to include("non_establishment")
      end

      it "hiển thị nút Thêm đầu mối" do
        get contact_points_path
        expect(response.body).to include(new_contact_point_path)
      end
    end
  end

  describe "current_zone_manager? bỏ qua khu vực đã xóa (C2)" do
    let!(:zone) { create(:zone, name: "KV C2") }
    let!(:unit) { create(:unit, name: "Đơn vị C2", zone: zone) }
    let!(:admin) { create(:user, :unit_admin, unit: unit) }

    before { zone.update!(manager_unit: unit) }

    it "khu vực còn → unit_admin quản lý khu vực thấy loại water_pump trong dropdown" do
      sign_in admin
      get contact_points_path
      html = Nokogiri::HTML(response.body)
      type_options = html.css("select#type option").map { |o| o["value"] }.compact
      expect(type_options).to include("water_pump")
    end

    it "khu vực đã xóa → unit_admin không còn là zone-manager, không thấy loại water_pump" do
      zone.update_column(:discarded_at, Time.current)
      sign_in admin
      get contact_points_path
      html = Nokogiri::HTML(response.body)
      type_options = html.css("select#type option").map { |o| o["value"] }.compact
      expect(type_options).not_to include("water_pump")
    end
  end

  describe "zone field on new/edit form" do
    let!(:zone_managed) { create(:zone, name: "KV Alpha") }
    let!(:zone_other) { create(:zone, name: "KV Beta") }
    let!(:unit_mgr) { create(:unit, name: "Đơn vị Quản lý", zone: zone_managed) }
    let!(:admin_mgr) { create(:user, :unit_admin, unit: unit_mgr) }

    before { zone_managed.update!(manager_unit: unit_mgr) }

    context "as unit admin who manages a zone" do
      before { sign_in admin_mgr }

      it "residential form auto-fills zone without dropdown" do
        get new_contact_point_path(type: "residential")
        expect(response.body).to include("KV Alpha")
        expect(response.body).not_to include("KV Beta")
        expect(response.body).not_to include("— Chọn khu vực —")
      end

      it "public form auto-fills zone without dropdown" do
        get new_contact_point_path(type: "public")
        expect(response.body).to include("KV Alpha")
        expect(response.body).not_to include("— Chọn khu vực —")
      end

      it "water_pump form auto-fills zone without dropdown" do
        get new_contact_point_path(type: "water_pump")
        expect(response.body).to include("KV Alpha")
        expect(response.body).not_to include("— Chọn khu vực —")
      end

      it "non_establishment form auto-fills zone without dropdown" do
        get new_contact_point_path(type: "non_establishment")
        expect(response.body).to include("KV Alpha")
        expect(response.body).not_to include("— Chọn khu vực —")
      end
    end

    context "as system admin" do
      before { sign_in system_admin }

      it "zone dropdown shows all zones" do
        get new_contact_point_path(type: "residential")
        expect(response.body).to include("KV Alpha")
        expect(response.body).to include("KV Beta")
        expect(response.body).to include("— Chọn khu vực —")
      end
    end

    context "as unit admin who does NOT manage any zone" do
      before { sign_in admin_b }

      it "residential NEW form does not show zone mode radio" do
        get new_contact_point_path(type: "residential")
        expect(response.body).not_to include("Khu vực (cấp khu vực")
      end

      it "residential EDIT form does not show zone mode radio either" do
        cp = create(:contact_point, :residential, unit: unit_b, name: "Test edit",
                    initial_personnel_counts: { ranks.last.id => 1 })
        get edit_contact_point_path(cp)
        expect(response.body).not_to include("Khu vực (cấp khu vực")
      end
    end
  end

  describe "DELETE /contact_points/:id (T59)" do
    before { sign_in system_admin }

    it "discard CP, xóa data kỳ đang mở (v2.4.0)" do
      cp = create(:contact_point, :residential, unit: unit_a, name: "ToDiscard",
                  initial_personnel_counts: { ranks.last.id => 2 })
      meter = create(:meter, contact_point: cp, name: "CT-D1")
      delete contact_point_path(cp)
      cp.reload
      expect(cp).to be_discarded
      expect(meter.reload).to be_discarded
      # v2.4.0: discard lúc đang mở kỳ → xóa data per kỳ đang mở để engine không
      # cảnh báo/tính toán sai cho đầu mối đã xóa (kỳ cũ giữ nguyên — xem model spec).
      expect(cp.personnel_entries.where(period: period)).to be_empty
    end
  end
end
