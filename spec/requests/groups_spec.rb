require "rails_helper"

RSpec.describe "Groups", type: :request do
  let!(:unit) { create(:unit) }
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }

  before { sign_in system_admin }

  describe "POST /groups" do
    it "tạo nhóm" do
      post groups_path, params: { group: { name: "Nhóm A", unit_id: unit.id } }
      expect(response).to redirect_to(groups_path)
      expect(Group.find_by(name: "Nhóm A")).to be_present
    end
  end

  describe "DELETE /groups/:id (T43 cascade nullify)" do
    it "discard nhóm + nullify group_id của contact_points kept" do
      group = create(:group, unit: unit, name: "Nhóm B")
      rank = period.ranks.create!(name: "R", quota: 1, position: 99)
      cp = create(:contact_point, :residential, unit: unit, group: group,
                  initial_personnel_counts: { rank.id => 1 })
      delete group_path(group)
      group.reload
      expect(group).to be_discarded
      expect(cp.reload.group_id).to be_nil
    end
  end
end
