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

      expect(response).to have_http_status(:unprocessable_content)
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

    context "as commander (zone-manager)" do
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

    context "as commander (non zone-manager)" do
      let!(:unit_b) { create(:unit, zone: zone, name: "Unit B") }
      let!(:cp_b) {
        create(:contact_point, :residential, unit: unit_b, name: "CP-B",
               initial_personnel_counts: { rank.id => 2 })
      }
      let(:commander_b) { create(:user, :commander, unit: unit_b) }
      before { sign_in commander_b }

      it "hiển thị dữ liệu đơn vị mình, inputs disabled" do
        get unit_config_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("CP-B")
        expect(response.body).not_to include("CP-1")
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

  describe "PATCH gây lỗi validation — re-render an toàn cho cả 6 vai trò" do
    # Bug gốc: nhánh lỗi của #update render :show mà không set @available_zones/
    # @available_units → SA gặp 500 (NoMethodError). Test phủ cả 6 vai trò để khẳng
    # định không vai trò nào bị 500, và fix chỉ tác động đường SA (5 vai trò kia không đổi).
    #
    # unit_zm là đơn vị quản lý khu vực, unit_plain thì không → tách bạch ZM/không-ZM.
    let!(:unit_zm) { create(:unit, zone: zone, name: "Đơn vị ZM") }
    let!(:unit_plain) { create(:unit, zone: zone, name: "Đơn vị thường") }

    before { zone.update!(manager_unit: unit_zm) }

    # rate > 100 → vi phạm numericality của UnitConfig (mọi vai trò có quyền sửa đều dính)
    def patch_invalid_rate(unit_id: nil)
      patch unit_config_path, params: {
        unit_id: unit_id,
        unit_config: { unit_public_rate: "150" }
      }
    end

    context "vai trò có quyền sửa → 422 + re-render form (không raise)" do
      it "system_admin (đường có bug, nay đã sửa): dropdown khu vực/đơn vị vẫn render" do
        sign_in create(:user, :system_admin)

        expect { patch_invalid_rate(unit_id: unit_plain.id) }.not_to raise_error

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Tỷ lệ công cộng đơn vị phải nhỏ hơn hoặc bằng 100")
        # Dropdown SA đọc @available_zones/@available_units → phải có tên đơn vị
        expect(response.body).to include(unit_plain.name)
      end

      it "unit_admin (không quản lý khu vực)" do
        sign_in create(:user, :unit_admin, unit: unit_plain)

        expect { patch_invalid_rate }.not_to raise_error

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Tỷ lệ công cộng đơn vị phải nhỏ hơn hoặc bằng 100")
      end

      it "unit_admin (quản lý khu vực)" do
        sign_in create(:user, :unit_admin, unit: unit_zm)

        expect { patch_invalid_rate }.not_to raise_error

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Tỷ lệ công cộng đơn vị phải nhỏ hơn hoặc bằng 100")
      end
    end

    context "vai trò chỉ đọc / ngoài nghiệp vụ → bị chặn, không 500" do
      it "commander (không quản lý khu vực) → redirect root (AccessDenied)" do
        sign_in create(:user, :commander, unit: unit_plain)

        expect { patch_invalid_rate }.not_to raise_error

        expect(response).to redirect_to(root_path)
      end

      it "commander (quản lý khu vực) → redirect root (AccessDenied)" do
        sign_in create(:user, :commander, unit: unit_zm)

        expect { patch_invalid_rate }.not_to raise_error

        expect(response).to redirect_to(root_path)
      end

      it "technician → redirect (không phải vai trò nghiệp vụ)" do
        sign_in create(:user) # role mặc định = technician

        expect { patch_invalid_rate }.not_to raise_error

        expect(response).to redirect_to(users_path)
      end
    end
  end

  describe "unit_coefficient option visibility" do
    # Reuse outer let!(:zone), let!(:unit), let!(:period), let!(:rank), let!(:cp) (CP-1)
    # which give us 1 unit residential CP already. Add 2 more unit CPs and 1 zone-direct CP.
    let!(:cp2) {
      create(:contact_point, :residential, unit: unit, name: "CP-2",
             initial_personnel_counts: { rank.id => 1 })
    }
    let!(:cp3) {
      create(:contact_point, :residential, unit: unit, name: "CP-3",
             initial_personnel_counts: { rank.id => 1 })
    }
    let!(:zone_cp) {
      create(:contact_point, :zone_residential, zone: zone, name: "Zone-CP-UC",
             initial_personnel_counts: { rank.id => 1 })
    }
    let(:system_admin) { create(:user, :system_admin) }

    before do
      zone.update!(manager_unit: unit)
      sign_in system_admin
    end

    it "CHIEU-khac-don-vi-zone-direct: GET unit config shows unit_coefficient option exactly for unit contact points (3 unit CPs, 0 zone CPs)" do
      get unit_config_path(unit_id: unit.id)
      expect(response).to have_http_status(:ok)
      # 3 unit residential CPs (CP-1, CP-2, CP-3) each get a unit_coefficient option
      occurrences = response.body.scan('value="unit_coefficient"').length
      expect(occurrences).to eq(3)
    end

    it "CHIEU-khac-don-vi-zone-direct: PATCH updating zone-direct contact point OD to unit_coefficient is rejected by model validation" do
      # Use unit_admin (zone-manager) for PATCH to avoid SA re-render path issue
      sign_in admin
      zone_od = OtherDeduction.find_by!(contact_point: zone_cp, period: period)
      original_type = zone_od.other_type

      patch unit_config_path, params: {
        other_deductions: {
          zone_od.id.to_s => {
            other_type: "unit_coefficient",
            other_value: zone_od.other_value.to_s,
            lock_version: zone_od.lock_version
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(zone_od.reload.other_type).to eq(original_type)
    end

    it "PATCH updating unit contact point OD to unit_coefficient succeeds" do
      unit_od = OtherDeduction.find_by!(contact_point: cp, period: period)

      patch unit_config_path, params: {
        unit_id: unit.id,
        other_deductions: {
          unit_od.id.to_s => {
            other_type: "unit_coefficient",
            other_value: unit_od.other_value.to_s,
            lock_version: unit_od.lock_version
          }
        }
      }

      expect(unit_od.reload.other_type).to eq("unit_coefficient")
    end

    it "GET unit config hiển thị nhãn i18n 'Theo hệ số (đơn vị)' cho đầu mối thuộc đơn vị" do
      # Xác nhận khoá i18n unit_config.other_deductions.types.unit_coefficient hiển thị đúng nhãn
      # (không chỉ kiểm tra value="unit_coefficient" mà kiểm tra cả text nhãn render ra)
      get unit_config_path(unit_id: unit.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Theo hệ số (đơn vị)")
    end
  end

  describe "system_admin sửa 'Khác' đầu mối zone-direct theo ngữ cảnh khu vực (#328)" do
    let(:system_admin) { create(:user, :system_admin) }
    # orphan_zone không có đơn vị nào → manager_unit_id nil (không auto-assign).
    let!(:orphan_zone) { create(:zone, name: "Khu vực mồ côi") }
    let!(:orphan_zone_cp) {
      create(:contact_point, :zone_residential, zone: orphan_zone, name: "Zone-CP-Orphan",
             initial_personnel_counts: { rank.id => 1 })
    }

    before { sign_in system_admin }

    it "CHIEU-khac-zone-direct-orphan: GET zone-context surface đầu mối zone-direct dù khu vực không có manager" do
      expect(orphan_zone.reload.manager_unit_id).to be_nil
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zone-CP-Orphan")
      expect(response.body).to include("thuộc khu vực")
      # Không có @unit → section "thuộc đơn vị" bị ẩn.
      expect(response.body).not_to include("thuộc đơn vị")
    end

    it "CHIEU-khac-zone-direct-sua-duoc: PATCH zone-context cập nhật 'Khác' của đầu mối zone-direct (BigDecimal)" do
      od = OtherDeduction.find_by!(contact_point: orphan_zone_cp, period: period)

      patch unit_config_path, params: {
        zone_id: orphan_zone.id,
        other_deductions: {
          od.id.to_s => { other_type: "fixed", other_value: "12.34", lock_version: od.lock_version }
        }
      }

      expect(response).to redirect_to(unit_config_path(zone_id: orphan_zone.id))
      od.reload
      expect(od.other_value).to eq(BigDecimal("12.34"))
      expect(od.other_type).to eq("fixed")
    end

    it "CHIEU-khac-zone-direct-trang-trong: chọn khu vực không có đầu mối zone-direct → hiện gợi ý" do
      empty_zone = create(:zone, name: "Khu vực rỗng")
      get unit_config_path(zone_id: empty_zone.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("unit_config.zone_context.empty"))
    end

    it "CHIEU-khac-zone-direct-vai-tro: chỉ system_admin vào được ngữ cảnh khu vực orphan; non-SA không thấy" do
      parse = ->(body) { Nokogiri::HTML(body) }

      # system_admin: thấy đầu mối + input không disabled (sửa được).
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response.body).to include("Zone-CP-Orphan")
      parse.call(response.body).css("input[type='number'], select").each do |input|
        next if input["type"] == "hidden" || input["id"]&.match?(/zone_id|unit_id/)
        expect(input["disabled"]).to be_nil,
          "SA: input '#{input['name']}' không được disabled"
      end

      # unit_admin (đơn vị 'unit', không quản lý orphan_zone): zone_id bị bỏ qua → không thấy.
      sign_in admin
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response.body).not_to include("Zone-CP-Orphan")

      # commander: cũng không thấy đầu mối zone orphan.
      sign_in create(:user, :commander, unit: unit)
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response.body).not_to include("Zone-CP-Orphan")

      # technician: không phải vai trò nghiệp vụ → BusinessRoleRequired chặn (redirect).
      sign_in create(:user)
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response).to have_http_status(:redirect)
    end

    it "PATCH không kèm unit_id lẫn zone_id (cả hai nil) → redirect an toàn, không 500" do
      expect {
        patch unit_config_path, params: {}
      }.not_to raise_error
      expect(response).to have_http_status(:redirect)
    end

    it "CHIEU-khac-zone-direct-orphan: khu vực từng có đơn vị quản lý, đơn vị bị xóa → vẫn sửa được 'Khác' zone-direct" do
      # Tạo đơn vị quản lý cho orphan_zone rồi xóa nó → clear_zone_manager_if_self set manager_unit_id nil.
      manager = create(:unit, zone: orphan_zone, name: "Đơn vị quản lý tạm")
      expect(orphan_zone.reload.manager_unit_id).to eq(manager.id)
      manager.discard
      expect(orphan_zone.reload.manager_unit_id).to be_nil

      od = OtherDeduction.find_by!(contact_point: orphan_zone_cp, period: period)
      patch unit_config_path, params: {
        zone_id: orphan_zone.id,
        other_deductions: {
          od.id.to_s => { other_type: "fixed", other_value: "7.50", lock_version: od.lock_version }
        }
      }
      expect(response).to redirect_to(unit_config_path(zone_id: orphan_zone.id))
      expect(od.reload.other_value).to eq(BigDecimal("7.50"))
    end

    it "CHIEU-khac-zone-direct-sua-duoc: PATCH zone-context lỗi validation → 422 re-render an toàn (không raise), giá trị giữ nguyên" do
      od = OtherDeduction.find_by!(contact_point: orphan_zone_cp, period: period)
      original_value = od.other_value

      expect {
        patch unit_config_path, params: {
          zone_id: orphan_zone.id,
          other_deductions: {
            od.id.to_s => { other_type: "fixed", other_value: "", lock_version: od.lock_version }
          }
        }
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
      expect(od.reload.other_value).to eq(original_value)
      # Dropdown khu vực vẫn render (chứng tỏ @zone + set_sa_filter_dropdowns sống sót re-render).
      expect(response.body).to include("Khu vực mồ côi")
    end
  end

  describe "unit_coefficient — chỉ huy đơn vị xem trang cấu hình" do
    # Test 4: commander viewing unit config cannot edit — select is disabled, no submit button.
    # Mirrors pattern from "view permission guards" context but scoped to unit_coefficient feature.
    let!(:cp_unit_coeff) {
      create(:contact_point, :residential, unit: unit, name: "CP-UC-CMD",
             initial_personnel_counts: { rank.id => 2 })
    }
    let!(:commander) { create(:user, :commander, unit: unit) }
    let(:html) { Nokogiri::HTML(response.body) }

    before do
      # Set the CP's OtherDeduction to unit_coefficient so the select is rendered with that type
      od = OtherDeduction.find_by!(contact_point: cp_unit_coeff, period: period)
      od.update!(other_type: "unit_coefficient", other_value: BigDecimal("-1"))
      sign_in commander
    end

    it "CHIEU-khac-don-vi-vai-tro: select kiểu khoản trừ bị disabled cho chỉ huy đơn vị" do
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CP-UC-CMD")
      html.css("select").each do |sel|
        next if sel["id"]&.match?(/zone_id|unit_id/)  # toolbar dropdowns
        expect(sel["disabled"]).to be_present,
          "Expected select '#{sel['name']}' to be disabled for commander"
      end
    end

    it "không hiển thị nút Lưu cấu hình cho chỉ huy đơn vị" do
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CP-UC-CMD")
      expect(html.css("input[name='commit']")).to be_empty
    end
  end

  describe "UI/UX improvements (#405)" do
    it "hiển thị giải thích 3 kiểu cột Khác dưới bảng other_deductions" do
      get unit_config_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cố định = số kWh cụ thể")
      expect(response.body).to include("Theo hệ số = hệ số × quân số đầu mối")
      expect(response.body).to include("Theo hệ số (đơn vị) = hệ số × (tổng quân số đơn vị − quân số đầu mối)")
    end

    it "placeholder thay đổi theo kiểu other_deduction (server-side default)" do
      od = OtherDeduction.find_by!(contact_point: cp, period: period)
      od.update!(other_type: "fixed")
      get unit_config_path
      doc = Nokogiri::HTML(response.body)
      value_input = doc.css("input[name='other_deductions[#{od.id}][other_value]']").first
      expect(value_input["placeholder"]).to eq("kWh")
    end

    it "placeholder là 'hệ số' khi kiểu là coefficient" do
      od = OtherDeduction.find_by!(contact_point: cp, period: period)
      od.update!(other_type: "coefficient")
      get unit_config_path
      doc = Nokogiri::HTML(response.body)
      value_input = doc.css("input[name='other_deductions[#{od.id}][other_value]']").first
      expect(value_input["placeholder"]).to eq("hệ số")
    end

    it "data attributes cho Stimulus other-deduction controller" do
      get unit_config_path
      doc = Nokogiri::HTML(response.body)
      row = doc.css("tr[data-controller='other-deduction']").first
      expect(row).to be_present
      expect(row["data-other-deduction-contact-point-personnel-value"]).to be_present
      expect(row["data-other-deduction-unit-total-personnel-value"]).to be_present
    end

    it "hiển thị nhãn ước tính cho kiểu hệ số" do
      od = OtherDeduction.find_by!(contact_point: cp, period: period)
      od.update!(other_type: "coefficient", other_value: -2)
      get unit_config_path
      expect(response.body).to include("Ước tính theo quân số hiện tại")
    end
  end
end
