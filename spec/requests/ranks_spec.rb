require "rails_helper"

RSpec.describe "Ranks", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }

  before { sign_in system_admin }

  describe "POST /ranks" do
    it "tạo rank cho kỳ đang mở" do
      post ranks_path, params: { rank: { name: "Test rank", quota: "100", position: 99 } }
      expect(response).to redirect_to(ranks_path)
      rank = Rank.find_by!(name: "Test rank")
      expect(rank.period).to eq(period)
    end
  end

  describe "DELETE /ranks/:id (T44)" do
    let!(:rank_main) { create(:rank, period: period, position: 1, name: "Rank chính") }
    let!(:rank_test) { create(:rank, period: period, position: 99, name: "Test") }

    it "cho xóa nếu count = 0 cho rank này" do
      unit = create(:unit)
      create(:contact_point, :residential, unit: unit,
             initial_personnel_counts: { rank_main.id => 5 })
      # rank_test có entry với count = 0 (seed callback)
      delete rank_path(rank_test)
      expect(Rank.where(id: rank_test.id)).to be_empty
    end

    it "chặn xóa nếu count > 0" do
      unit = create(:unit)
      create(:contact_point, :residential, unit: unit,
             initial_personnel_counts: { rank_main.id => 5, rank_test.id => 3 })
      delete rank_path(rank_test)
      expect(Rank.where(id: rank_test.id)).to be_present
      expect(flash[:alert]).to include("Phải chuyển hết quân số")
    end
  end
end
