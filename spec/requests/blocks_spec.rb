require "rails_helper"

RSpec.describe "Blocks", type: :request do
  let!(:unit) { create(:unit) }
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }

  before { sign_in system_admin }

  describe "GET /blocks" do
    it "trả về 200" do
      create(:block, unit: unit, name: "Phòng Tham mưu")
      get blocks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Phòng Tham mưu")
    end
  end

  describe "POST /blocks" do
    it "tạo khối" do
      post blocks_path, params: { block: { name: "Phòng mới", unit_id: unit.id } }
      expect(response).to redirect_to(blocks_path)
      expect(Block.find_by(name: "Phòng mới")).to be_present
    end
  end

  describe "DELETE /blocks/:id (T42 cascade nullify)" do
    it "discard khối + nullify children" do
      block = create(:block, unit: unit, name: "Phòng X")
      group = create(:group, unit: unit, block: block, name: "Nhóm trong khối")
      cp = create(:contact_point, :residential, unit: unit, block: block,
                  initial_personnel_counts: { period.ranks.create!(name: "R", quota: 1, position: 99).id => 1 })
      delete block_path(block)
      block.reload
      expect(block).to be_discarded
      expect(group.reload.block_id).to be_nil
      expect(cp.reload.block_id).to be_nil
    end
  end
end
