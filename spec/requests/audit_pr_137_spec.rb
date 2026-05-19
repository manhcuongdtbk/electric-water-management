require "rails_helper"

# Integration tests cho các test plan items của PR #137.
# Mỗi item tương ứng 1 finding hoặc fix trong audit 12 nhóm.
RSpec.describe "PR #137 audit cleanup verification", type: :request do
  let(:system_admin) { create(:user, :system_admin, force_password_change: false) }
  let(:technician)   { create(:user, force_password_change: false) }

  describe "Group 1 #1 — Public CP form bỏ block/group" do
    before { sign_in system_admin }

    it "form public không có dropdown khối/nhóm" do
      get new_contact_point_path(type: "public")
      expect(response.body).to include('name="contact_point[name]"')
      expect(response.body).not_to include('name="contact_point[block_id]"')
      expect(response.body).not_to include('name="contact_point[group_id]"')
    end

    it "controller permit không cho phép block_id/group_id cho public" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      block = create(:block, unit: unit)
      create(:period, closed: false, year: 2099, month: 3, unit_price: 3000)
      post contact_points_path, params: {
        contact_point: {
          name: "CP-public-test", contact_point_type: "public",
          unit_id: unit.id, block_id: block.id,
          meters_attributes: { "0" => { name: "CT-pub", no_loss: "0" } }
        }
      }
      cp = ContactPoint.find_by(name: "CP-public-test")
      expect(cp).to be_present
      expect(cp.block_id).to be_nil
    end

    it "model validate_public_constraints chặn block/group ngay cả khi bypass controller" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      block = create(:block, unit: unit)
      cp = ContactPoint.new(name: "X", contact_point_type: "public", unit: unit, block: block)
      expect(cp).not_to be_valid
      expect(cp.errors[:block_id]).to include(I18n.t("activerecord.errors.models.contact_point.attributes.block_id.must_be_blank"))
    end
  end

  describe "Group 1 #3 — Residential CP form: block/group có data-unit-id" do
    before { sign_in system_admin }

    it "block options trong form residential có data-unit-id" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      block = create(:block, unit: unit, name: "Khối X")
      get new_contact_point_path(type: "residential")
      expect(response.body).to include(%(data-unit-id="#{unit.id}"))
      expect(response.body).to include("Khối X")
    end
  end

  describe "Group 1 #2 — Pump allocation form: unit/contact_point có data-zone-id" do
    before { sign_in system_admin }

    it "options unit + contact_point có data-zone-id" do
      zone = create(:zone)
      unit = create(:unit, zone: zone, name: "DV-Z1")
      create(:period, closed: false, year: 2099, month: 1, unit_price: 3000)
      get new_pump_allocation_path
      expect(response.body).to include(%(data-zone-id="#{zone.id}"))
      expect(response.body).to include("DV-Z1")
    end

    it "model reject pump_allocation với unit khác zone" do
      zone_a = create(:zone)
      zone_b = create(:zone)
      unit_b = create(:unit, zone: zone_b)
      period = create(:period, closed: false, year: 2099, month: 2, unit_price: 3000)
      alloc = PumpAllocation.new(zone: zone_a, unit: unit_b, period: period, coefficient: 1)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:unit_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.unit_id.zone_mismatch"))
    end
  end

  describe "Group 4 — Technician hit /dashboard → redirect /users + flash" do
    before { sign_in technician }

    it "redirect to /users with access_denied flash" do
      get root_path
      expect(response).to redirect_to(users_path)
      follow_redirect!
      expect(flash[:alert]).to eq(I18n.t("errors.access_denied"))
    end

    it "redirect for /billing, /history, /meter_entries, /pump_entries, /unit_config" do
      %w[/billing /history /meter_entries /pump_entries /unit_config].each do |path|
        get path
        expect(response).to redirect_to(users_path), "expected redirect from #{path}"
      end
    end
  end

  describe "Group 5 #1 — Edit closed-period rank → redirect with flash" do
    before { sign_in system_admin }

    it "redirect to ranks_path khi rank thuộc kỳ đã đóng" do
      closed_period = create(:period, closed: true, year: 2098, month: 6)
      rank = create(:rank, period: closed_period, name: "OldRank", position: 99, quota: 100)
      _open_period = create(:period, closed: false, year: 2099, month: 7, unit_price: 3000)

      get edit_rank_path(rank)
      expect(response).to redirect_to(ranks_path)
      expect(flash[:alert]).to eq(I18n.t("ranks.flash.belongs_to_closed_period"))

      patch rank_path(rank), params: { rank: { quota: 999 } }
      expect(response).to redirect_to(ranks_path)
      expect(rank.reload.quota).to eq(100)
    end
  end

  describe "Group 5 #2 — Edit closed-period pump_allocation → redirect" do
    before { sign_in system_admin }

    it "redirect to pump_allocations_path khi allocation thuộc kỳ đã đóng" do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      closed_period = create(:period, closed: true, year: 2097, month: 5)
      alloc = create(:pump_allocation, zone: zone, unit: unit, period: closed_period, coefficient: 1)
      _open_period = create(:period, closed: false, year: 2099, month: 8, unit_price: 3000)

      get edit_pump_allocation_path(alloc)
      expect(response).to redirect_to(pump_allocations_path)
      expect(flash[:alert]).to eq(I18n.t("pump_allocations.flash.belongs_to_closed_period"))

      patch pump_allocation_path(alloc), params: { pump_allocation: { coefficient: 99 } }
      expect(response).to redirect_to(pump_allocations_path)
      expect(alloc.reload.coefficient).to eq(1)
    end
  end

  describe "Group 3 — Discarded CP không hiển thị trên form meter_entries" do
    before { sign_in system_admin }

    it "load_readings filter discarded CPs" do
      period = create(:period, closed: false, year: 2099, month: 9, unit_price: 3000)
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      kept_cp = create(:contact_point, :residential, unit: unit, name: "KeptCP",
                       initial_personnel_counts: { create(:rank, period: period).id => 1 })
      discarded_cp = create(:contact_point, :residential, unit: unit, name: "DiscardedCP",
                            initial_personnel_counts: { create(:rank, period: period, position: 2).id => 1 })
      create(:meter, contact_point: kept_cp, name: "Meter-Kept")
      create(:meter, contact_point: discarded_cp, name: "Meter-Discarded")
      discarded_cp.discard

      get meter_entries_path
      expect(response.body).to include("KeptCP")
      expect(response.body).not_to include("DiscardedCP")
    end
  end

  describe "Group 1 #5 — non_establishment personnel_count propagate snapshot" do
    before { sign_in system_admin }

    it "update personnel_count → snapshot kỳ đang mở cập nhật theo" do
      period = create(:period, closed: false, year: 2099, month: 10, unit_price: 3000)
      zone = create(:zone)
      ne_cp = create(:contact_point, :non_establishment, zone: zone, name: "NE-CP", personnel_count: 5)
      snapshot = ne_cp.non_establishment_snapshots.find_by(period: period)
      expect(snapshot.personnel_count).to eq(5)

      patch contact_point_path(ne_cp), params: {
        contact_point: { name: "NE-CP", personnel_count: 8 }
      }
      ne_cp.reload
      expect(ne_cp.personnel_count).to eq(8)
      expect(snapshot.reload.personnel_count).to eq(8)
    end
  end

  describe "Group 10 — Audit logs KHÔNG hiển thị encrypted_password" do
    # User cập nhật cả display_name (track) lẫn password (ignore) → version row có
    # display_name change, không có encrypted_password. Nếu password ĐƠN ĐỘC thay đổi
    # thì không có version row (vì attr duy nhất bị ignore) — đó cũng là behavior mong muốn.
    it "PaperTrail::Version cho User update không chứa encrypted_password" do
      user = create(:user, :unit_admin, force_password_change: false, unit: create(:unit))
      PaperTrail.request(whodunnit: system_admin.id) do
        user.update!(display_name: "Tên mới", password: "NewPass@123", password_confirmation: "NewPass@123")
      end
      latest_version = user.versions.where(event: "update").last
      expect(latest_version).to be_present
      changes_hash = YAML.unsafe_load(latest_version.object_changes)
      expect(changes_hash.keys).to include("display_name")
      expect(changes_hash.keys).not_to include("encrypted_password")
    end

    it "audit_logs show không render encrypted_password trong table" do
      sign_in system_admin
      user = create(:user, :unit_admin, force_password_change: false, unit: create(:unit))
      PaperTrail.request(whodunnit: system_admin.id) do
        user.update!(display_name: "Tên mới", password: "NewPass@123", password_confirmation: "NewPass@123")
      end
      version = user.versions.where(event: "update").last
      get audit_log_path(version)
      expect(response.body).not_to include("encrypted_password")
    end

    it "User update chỉ password (không attr nào khác) → không tạo version (encrypted_password bị ignore)" do
      user = create(:user, :unit_admin, force_password_change: false, unit: create(:unit))
      before_count = user.versions.where(event: "update").count
      PaperTrail.request(whodunnit: system_admin.id) do
        user.update!(password: "NewPass@123", password_confirmation: "NewPass@123")
      end
      after_count = user.versions.where(event: "update").count
      expect(after_count).to eq(before_count) # không có version nào được tạo
    end
  end

  describe "Group 6 — Display format VN" do
    before { sign_in system_admin }

    it "/pricing đơn giá hiển thị format VN (dấu chấm hàng nghìn)" do
      create(:period, closed: false, year: 2099, month: 11, unit_price: 3500, savings_rate: 5, division_public_rate: 10, water_pump_standard: 9.45)
      get pricing_path
      # 3500 → "3.500 đ"
      expect(response.body).to match(/3\.500\s*đ/)
    end

    it "/ranks quota hiển thị format VN" do
      period = create(:period, closed: false, year: 2099, month: 12, unit_price: 3000)
      create(:rank, period: period, name: "TestRank", position: 1, quota: 1234.5)
      get ranks_path
      # 1234.5 → "1.234,5"
      expect(response.body).to match(/1\.234,5/)
    end
  end

  describe "Group 11 — N+1 preload check" do
    before { sign_in system_admin }

    it "billing query preload unit.zone (no extra query for effective_zone)" do
      period = create(:period, closed: false, year: 2099, month: 6, unit_price: 3000)
      zone = create(:zone, name: "ZoneA")
      unit = create(:unit, zone: zone)
      cp = create(:contact_point, :residential, unit: unit, name: "CP1",
                  initial_personnel_counts: { create(:rank, period: period).id => 1 })
      create(:calculation, contact_point: cp, period: period, total_personnel: 1)

      scope = Billing::Query.base_scope(period, Ability.new(system_admin))
      calcs = scope.to_a

      # Sau khi đã load, không được fire query thêm khi access effective_zone
      queries = []
      callback = ->(_n, _s, _f, _id, payload) { queries << payload[:sql] unless payload[:sql].start_with?("BEGIN", "COMMIT", "SAVEPOINT", "RELEASE") }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        calcs.each { |c| c.contact_point.effective_zone&.name }
      end
      expect(queries).to be_empty, "Expected 0 queries when accessing effective_zone after preload, got #{queries.size}: #{queries.first(3).inspect}"
    end
  end
end
