require "rails_helper"

# Integration test cho v2.3.0 StructureChangeGuard ở tất cả structure controllers.
# Mỗi controller test 3 trạng thái: no open period, open == latest, open != latest.
RSpec.describe "v2.3.0 StructureChangeGuard integration", type: :request do
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let!(:zone) {
    Zone.create!(name: "V230-int-zone", main_meters_attributes: [{ name: "V230-int-mm" }])
  }
  let!(:unit) { create(:unit, zone: zone, name: "V230-int-unit") }
  let!(:block) { create(:block, unit: unit, name: "V230-int-block") }
  let!(:group) { create(:group, unit: unit, name: "V230-int-group") }
  let!(:residential_cp) {
    cp = ContactPoint.new(name: "V230-int-cp", contact_point_type: "residential",
                          unit: unit, block: block, group: group,
                          initial_personnel_counts: {})
    cp.meters.build(name: "V230-int-meter")
    cp.save!(validate: false)
    cp
  }

  let(:expected_message) {
    I18n.t("services.period_service.errors.structure_change_blocked_old_period")
  }

  context "không có kỳ nào mở (giai đoạn thiết lập ban đầu — Item 10)" do
    it "cho phép GET /zones/new" do
      get new_zone_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /units/new" do
      get new_unit_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /blocks/new" do
      get new_block_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /groups/new" do
      get new_group_path
      expect(response).to have_http_status(:ok)
    end

    # contact_points và ranks cần kỳ mở để tạo (PeriodGuard), nên skip ở scenario này
  end

  context "kỳ mở là kỳ mới nhất (Item 11)" do
    let!(:period_jan) { create(:period, year: 2099, month: 1, closed: true) }
    let!(:period_feb) { create(:period, year: 2099, month: 2, closed: false) }

    it "cho phép GET /zones/new" do
      get new_zone_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /units/new" do
      get new_unit_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /blocks/new" do
      get new_block_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /groups/new" do
      get new_group_path
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /contact_points/new (loại residential)" do
      get new_contact_point_path, params: { contact_point_type: "residential" }
      expect(response).to have_http_status(:ok)
    end

    it "cho phép GET /ranks/new" do
      get new_rank_path
      expect(response).to have_http_status(:ok)
    end
  end

  context "kỳ mở KHÔNG phải kỳ mới nhất (đang mở lại kỳ cũ — Items 8 + 9)" do
    let!(:period_jan) { create(:period, year: 2099, month: 1, closed: false) }
    let!(:period_feb) { create(:period, year: 2099, month: 2, closed: true) }
    let!(:period_mar) { create(:period, year: 2099, month: 3, closed: true) }

    describe "ZonesController (Item 8)" do
      it "chặn GET new" do
        get new_zone_path
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn POST create" do
        post zones_path, params: {
          zone: { name: "ko-tao-duoc", main_meters_attributes: [{ name: "x" }] }
        }
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn GET edit" do
        get edit_zone_path(zone)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn DELETE /zones/:id" do
        delete zone_path(zone)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
        expect(zone.reload.discarded_at).to be_nil
      end
    end

    describe "UnitsController (Item 9)" do
      it "chặn GET new" do
        get new_unit_path
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn POST create" do
        post units_path, params: { unit: { name: "ko-tao-duoc", zone_id: zone.id } }
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn GET edit" do
        get edit_unit_path(unit)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn DELETE /units/:id" do
        delete unit_path(unit)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
        expect(unit.reload.discarded_at).to be_nil
      end
    end

    describe "ContactPointsController (Item 9)" do
      it "chặn GET new" do
        get new_contact_point_path, params: { contact_point_type: "residential" }
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn POST create (cho dù có PeriodGuard cho phép vì có kỳ mở)" do
        post contact_points_path, params: {
          contact_point: { name: "ko-tao", contact_point_type: "residential", unit_id: unit.id }
        }
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end
    end

    describe "BlocksController (Item 9)" do
      it "chặn GET new" do
        get new_block_path
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn DELETE /blocks/:id" do
        delete block_path(block)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end
    end

    describe "GroupsController (Item 9)" do
      it "chặn GET new" do
        get new_group_path
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end

      it "chặn DELETE /groups/:id" do
        delete group_path(group)
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end
    end

    describe "RanksController (Item 9)" do
      it "chặn GET new" do
        get new_rank_path
        expect(response).to redirect_to(/.+/)
        expect(flash[:alert]).to eq(expected_message)
      end
    end
  end
end
