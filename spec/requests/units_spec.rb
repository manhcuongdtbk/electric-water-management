require "rails_helper"

RSpec.describe "Units", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let(:zone) { create(:zone) }

  before { sign_in system_admin }

  describe "POST /units (T29, T32)" do
    it "T29: tạo unit" do
      post units_path, params: { unit: { name: "Đơn vị A", zone_id: zone.id } }
      expect(response).to redirect_to(units_path)
      unit = Unit.find_by!(name: "Đơn vị A")
      expect(unit.zone).to eq(zone)
    end

    it "T32: unit đầu tiên tự động là manager" do
      post units_path, params: { unit: { name: "Đơn vị A", zone_id: zone.id } }
      unit = Unit.find_by!(name: "Đơn vị A")
      expect(zone.reload.manager_unit_id).to eq(unit.id)
    end
  end

  describe "PATCH /units/:id (T30)" do
    it "chặn đổi zone_id" do
      zone_b = create(:zone)
      unit = create(:unit, zone: zone)
      patch unit_path(unit), params: { unit: { name: "Tên mới", zone_id: zone_b.id } }
      expect(response).to redirect_to(units_path)
      unit.reload
      expect(unit.zone_id).to eq(zone.id)
      expect(unit.name).to eq("Tên mới")
    end
  end

  describe "DELETE /units/:id (T39, T41)" do
    let(:unit) { create(:unit, zone: zone) }
    let!(:period) { create(:period, closed: false) }

    it "T39: chặn xóa khi còn contact_point kept" do
      rank = period.ranks.create!(name: "R", quota: 1, position: 1)
      create(:contact_point, :residential, unit: unit, initial_personnel_counts: { rank.id => 1 })
      delete unit_path(unit)
      unit.reload
      expect(unit).not_to be_discarded
      expect(flash[:alert]).to include("Phải xóa hết đầu mối")
    end

    it "T41: xóa unit là manager → zone.manager_unit_id = nil" do
      u = unit  # force unit creation first
      expect(zone.reload.manager_unit_id).to eq(u.id)
      delete unit_path(u)
      expect(zone.reload.manager_unit_id).to be_nil
    end
  end
end
