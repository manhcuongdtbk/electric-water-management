require "rails_helper"

RSpec.describe "UnitConfig", type: :request do
  let!(:unit) { create(:unit) }
  let(:admin) { create(:user, :unit_admin, unit: unit) }
  let!(:period) { create(:period, closed: false) }
  let!(:rank) { create(:rank, period: period, name: "R1", position: 1) }
  let!(:cp) {
    create(:contact_point, :residential, unit: unit, name: "CP-1",
           initial_personnel_counts: { rank.id => 1 })
  }
  let!(:unit_config) { UnitConfig.create!(unit: unit, period: period, unit_public_rate: 0) }

  before { sign_in admin }

  describe "GET /unit_config" do
    it "trả về 200 và hiển thị unit_public_rate + other_deductions" do
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tỷ lệ công cộng đơn vị")
      expect(response.body).to include("CP-1")
    end
  end

  describe "PATCH /unit_config (batch save)" do
    it "lưu unit_public_rate + other_deductions trong 1 transaction" do
      uc = UnitConfig.find_by!(unit: unit, period: period)
      od = OtherDeduction.find_by!(contact_point: cp, period: period)

      patch unit_config_path, params: {
        unit_config: { unit_public_rate: "5.5", lock_version: uc.lock_version },
        other_deductions: {
          od.id.to_s => { other_type: "coefficient", other_value: "-1.5", lock_version: od.lock_version }
        }
      }

      expect(response).to redirect_to(unit_config_path(unit_id: unit.id))
      expect(uc.reload.unit_public_rate.to_s).to eq("5.5")
      expect(od.reload.other_type).to eq("coefficient")
      expect(od.reload.other_value.to_s).to eq("-1.5")
    end

    it "rollback toàn bộ nếu 1 entry fail" do
      uc = UnitConfig.find_by!(unit: unit, period: period)
      od = OtherDeduction.find_by!(contact_point: cp, period: period)
      original_rate = uc.unit_public_rate

      patch unit_config_path, params: {
        unit_config: { unit_public_rate: "5.0", lock_version: uc.lock_version },
        other_deductions: {
          od.id.to_s => { other_type: "fixed", other_value: "not_a_number", lock_version: od.lock_version }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(uc.reload.unit_public_rate).to eq(original_rate)
    end
  end

  describe "khi không có kỳ đang mở" do
    it "show vẫn truy cập được" do
      period.update!(closed: true)
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Không có kỳ đang mở")
    end

    it "update bị PeriodGuard chặn" do
      period.update!(closed: true)
      patch unit_config_path, params: { unit_config: { unit_public_rate: "5" } }
      expect(response).to redirect_to("/")
    end
  end
end
