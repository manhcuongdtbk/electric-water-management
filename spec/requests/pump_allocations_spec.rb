require "rails_helper"

RSpec.describe "PumpAllocations", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }
  let!(:zone) { create(:zone) }
  let!(:unit) { create(:unit, zone: zone) }

  before { sign_in system_admin }

  describe "GET /pump_allocations" do
    it "trả về 200" do
      get pump_allocations_path
      expect(response).to have_http_status(:ok)
    end

    it "ẩn allocation khi unit đã bị discard" do
      alloc = create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil)
      get pump_allocations_path
      expect(response.body).to include(unit.name)

      unit.discard
      get pump_allocations_path
      expect(response.body).not_to include(unit.name)
    end

    it "ẩn allocation khi contact_point đã bị discard" do
      contact_point = create(:contact_point, :residential, unit: unit, zone: nil)
      alloc = create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: contact_point)
      get pump_allocations_path
      expect(response.body).to include(contact_point.name)

      contact_point.discard
      get pump_allocations_path
      expect(response.body).not_to include(contact_point.name)
    end
  end

  describe "POST /pump_allocations" do
    it "tạo phân bổ cho unit" do
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: unit.id,
          coefficient: "1", fixed_percentage: ""
        }
      }
      expect(response).to redirect_to(pump_allocations_path)
      expect(PumpAllocation.count).to eq(1)
    end

    it "T53: chặn khi tổng fixed_percentage > 100" do
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             contact_point: nil, fixed_percentage: 80, coefficient: 1)
      another_unit = create(:unit, zone: zone)
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: another_unit.id,
          coefficient: "0", fixed_percentage: "30"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("không được vượt quá 100")
    end
  end
end
