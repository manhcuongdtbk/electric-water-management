require "rails_helper"

RSpec.describe "UnitConfig", type: :request do
  let!(:zone) { create(:zone) }
  let!(:unit) { create(:unit, zone: zone) }
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

  describe "view permission guards" do
    let(:html) { Nokogiri::HTML(response.body) }

    context "as commander" do
      let(:commander) { create(:user, :commander, unit: unit) }
      before { sign_in commander }

      it "hiển thị dữ liệu nhưng tất cả input đều disabled" do
        get unit_config_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CP-1")
        html.css("input[type='number'], select").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_present,
            "Expected input '#{input['name']}' to be disabled for commander"
        end
      end

      it "không hiển thị nút Lưu cấu hình" do
        get unit_config_path
        expect(html.css("input[name='commit']")).to be_empty
      end
    end

    context "as unit_admin (zone-manager)" do
      let!(:zone_cp) {
        create(:contact_point, :zone_residential, zone: zone, name: "Zone-CP-1",
               initial_personnel_counts: { rank.id => 1 })
      }
      before do
        zone.update!(manager_unit: unit)
        sign_in admin
      end

      it "hiển thị cả OD thuộc đơn vị và OD thuộc khu vực" do
        get unit_config_path
        expect(response.body).to include("thuộc đơn vị")
        expect(response.body).to include("thuộc khu vực")
        expect(response.body).to include("CP-1")
        expect(response.body).to include("Zone-CP-1")
      end

      it "input không bị disabled" do
        get unit_config_path
        html.css("input[type='number'], select").each do |input|
          next if input["type"] == "hidden"
          expect(input["disabled"]).to be_nil,
            "Expected input '#{input['name']}' to NOT be disabled for zone-manager"
        end
      end

      it "hiển thị nút Lưu cấu hình" do
        get unit_config_path
        expect(html.css("input[name='commit']")).to be_present
      end
    end

    context "as unit_admin (non zone-manager)" do
      it "không hiển thị section OD thuộc khu vực" do
        get unit_config_path
        expect(response.body).to include("thuộc đơn vị")
        expect(response.body).not_to include("thuộc khu vực")
      end
    end

    context "as system_admin viewing zone-managing unit" do
      let(:system_admin) { create(:user, :system_admin) }
      let!(:zone_cp) {
        create(:contact_point, :zone_residential, zone: zone, name: "Zone-CP-SA",
               initial_personnel_counts: { rank.id => 1 })
      }
      before do
        zone.update!(manager_unit: unit)
        sign_in system_admin
      end

      it "hiển thị cả OD đơn vị và OD khu vực khi chọn đơn vị quản lý khu vực" do
        get unit_config_path(unit_id: unit.id)
        expect(response.body).to include("thuộc đơn vị")
        expect(response.body).to include("thuộc khu vực")
        expect(response.body).to include("Zone-CP-SA")
      end
    end

    context "SA dropdown: kỳ mới nhất không hiện unit đã xóa" do
      let(:system_admin) { create(:user, :system_admin) }
      let!(:unit_b) { create(:unit, zone: zone, name: "Đơn vị B") }

      before do
        # Xóa unit_b
        unit_b.discard
        sign_in system_admin
      end

      it "dropdown không chứa unit đã xóa khi kỳ mới nhất mở" do
        get unit_config_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit.name)
        expect(response.body).not_to include("Đơn vị B")
      end
    end

    context "SA dropdown: kỳ cũ mở lại hiện unit đã xóa" do
      let(:system_admin) { create(:user, :system_admin) }
      let!(:unit_b) { create(:unit, zone: zone, name: "Đơn vị B") }

      before do
        sign_in system_admin
        # Đóng kỳ hiện tại, mở kỳ mới, đóng kỳ mới, xóa unit, mở lại kỳ cũ
        period.update!(closed: true)
        @period_2 = PeriodService.new.open_new_period.period
        unit_b.discard
        @period_2.update!(closed: true)
        PeriodService.new.reopen_period(period)
      end

      it "dropdown chứa unit đã xóa khi kỳ cũ mở lại" do
        get unit_config_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit.name)
        expect(response.body).to include("Đơn vị B")
      end

      it "SA chọn unit đã xóa → xem được config kỳ cũ" do
        get unit_config_path(unit_id: unit_b.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "SA dropdown: kỳ cũ không hiện unit tạo nhầm rồi xóa (không có data)" do
      let(:system_admin) { create(:user, :system_admin) }

      before do
        sign_in system_admin
        # Tạo unit_c rồi xóa ngay trong cùng kỳ → UnitConfig bị cleanup
        unit_c = create(:unit, zone: zone, name: "Đơn vị tạm")
        unit_c.discard
        # Đóng kỳ, mở kỳ mới, đóng, mở lại kỳ cũ
        period.update!(closed: true)
        period_2 = PeriodService.new.open_new_period.period
        period_2.update!(closed: true)
        PeriodService.new.reopen_period(period)
      end

      it "dropdown không chứa unit tạo nhầm rồi xóa" do
        get unit_config_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit.name)
        expect(response.body).not_to include("Đơn vị tạm")
      end
    end
  end
end
