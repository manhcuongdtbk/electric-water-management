# Sửa "Khác" của đầu mối zone-direct theo ngữ cảnh khu vực (#328) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho phép quản trị viên hệ thống sửa khoản trừ "Khác" của đầu mối sinh hoạt zone-direct theo ngữ cảnh khu vực (độc lập `manager_unit_id`), để giá trị không kẹt khi khu vực không có đơn vị quản lý (bug #328).

**Architecture:** Tách nguồn `zone_ids` của scope zone-direct trong `UnitConfigController` theo ngữ cảnh (`@unit` → zones do unit quản lý; `@zone` + SA → `[@zone.id]`). `#show` đã resolve `@zone/@unit`; thêm nhánh zone-context cho `#update`. View render form khi có `@unit` **hoặc** `@zone`, ẩn section đơn vị khi không có `@unit`, thêm empty-state hint. Đường manager-unit hiện có giữ nguyên cho non-SA.

**Tech Stack:** Rails 8, CanCanCan (`accessible_by`/`authorize!`), RSpec request + system (Capybara), i18n (`config/locales/vi.yml`).

**Spec:** [`docs/superpowers/specs/2026-06-13-khac-zone-direct-sua-duoc-design.md`](../specs/2026-06-13-khac-zone-direct-sua-duoc-design.md) (ADR-034).

---

## File Structure

- Modify: `app/controllers/unit_config_controller.rb` — tổng quát hóa `scope_zone_other_deductions`, thêm `zone_other_deduction_zone_ids` + `resolve_zone_for_update`, nhánh zone-context cho `#update`.
- Modify: `app/views/unit_config/show.html.erb` — gate form theo `(@unit || @zone)`, ẩn section đơn vị khi không `@unit`, hidden field unit_id/zone_id, `can_edit` cho zone-context, empty-state hint.
- Modify: `config/locales/vi.yml` — khoá `unit_config.zone_context.empty`.
- Modify: `spec/requests/unit_config_spec.rb` — test request 4 chiều (`CHIEU-khac-zone-direct-*`).
- Modify: `spec/system/unit_config_spec.rb` — test đường người dùng bấm dropdown khu vực + empty-state.
- Modify: `docs/THUAT_NGU.md` — định nghĩa "probe" (§3) + bump version + changelog.

**Lưu ý chạy test:** mọi lệnh test chạy trong Docker: `bin/docker rspec <path>`.

---

## Task 1: GET — surface đầu mối zone-direct theo ngữ cảnh khu vực (controller scope + view)

**Files:**
- Test: `spec/requests/unit_config_spec.rb`
- Modify: `app/controllers/unit_config_controller.rb`
- Modify: `app/views/unit_config/show.html.erb`

- [ ] **Step 1: Viết test thất bại (GET orphan zone surface CP)**

Thêm vào cuối `spec/requests/unit_config_spec.rb`, **trước** dòng `end` cuối cùng của `RSpec.describe`:

```ruby
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
  end
```

- [ ] **Step 2: Chạy test, xác nhận FAIL**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "CHIEU-khac-zone-direct-orphan"`
Expected: FAIL — body không chứa "Zone-CP-Orphan" (scope hiện trả rỗng khi không có manager; view không render form khi `@unit` nil).

- [ ] **Step 3: Sửa controller — tổng quát hóa scope zone-direct**

Trong `app/controllers/unit_config_controller.rb`, thay method `scope_zone_other_deductions` (hiện ở khoảng dòng 112-123) bằng:

```ruby
  def scope_zone_other_deductions
    return OtherDeduction.none unless @period
    zone_ids = zone_other_deduction_zone_ids
    return OtherDeduction.none if zone_ids.empty?
    OtherDeduction.joins(:contact_point).includes(:contact_point)
                  .where(period: @period,
                         contact_points: { zone_id: zone_ids,
                                           unit_id: nil,
                                           contact_point_type: "residential" })
                  .accessible_by(current_ability)
                  .order("contact_points.name")
  end

  # Nguồn zone_ids cho khoản trừ "Khác" của đầu mối zone-direct:
  # - @unit có → các khu vực do đơn vị này quản lý (đường manager-unit, gồm non-SA).
  # - @unit nil & @zone có & SA → đúng khu vực đang chọn (ngữ cảnh khu vực, ADR-034).
  def zone_other_deduction_zone_ids
    if @unit
      Zone.kept.where(manager_unit_id: @unit.id).pluck(:id)
    elsif @zone && current_user.system_admin?
      [@zone.id]
    else
      []
    end
  end
```

- [ ] **Step 4: Sửa view — render form ở ngữ cảnh khu vực, ẩn section đơn vị khi không `@unit`**

Thay toàn bộ nội dung `app/views/unit_config/show.html.erb` bằng:

```erb
<% page_title "Cấu hình đơn vị" %>

<% if @unit.nil? && !current_user.system_admin? %>
  <div class="bg-yellow-50 border border-yellow-200 rounded p-3 text-sm text-yellow-800">
    Bạn chưa được gán đơn vị nào. Vui lòng liên hệ quản trị viên hệ thống.
  </div>
<% end %>


<% if current_user.system_admin? %>
  <%= render "shared/list_toolbar",
        url: unit_config_path,
        total_count: 0,
        show_search: false,
        show_per_page: false,
        show_total: false,
        filters: [
          { label: "Khu vực:", param: :zone_id,
            options: @available_zones.pluck(:name, :id), selected: @zone&.id,
            children: [:unit_id], blank_text: "— Chọn khu vực —" },
          { label: "Đơn vị:", param: :unit_id,
            options: @available_units.pluck(:name, :id), selected: @unit&.id,
            blank_text: "— Chọn đơn vị —" }
        ] %>
<% end %>

<% if (@unit || @zone) && current_period %>
  <% can_edit = !no_open_period? && (@unit ? (@unit_config ? can?(:update, @unit_config) : can?(:update, UnitConfig.new(unit: @unit, period: current_period))) : can?(:update, OtherDeduction)) %>
  <%= form_with url: unit_config_path, method: :patch, local: true, class: "space-y-6" do |f| %>
    <%= hidden_field_tag(@unit ? :unit_id : :zone_id, @unit ? @unit.id : @zone.id) %>

    <!-- Phần 1: unit_public_rate -->
    <% if @unit_config %>
      <div class="bg-white rounded-lg shadow border border-gray-200 p-6">
        <h3 class="text-base font-semibold text-gray-900 mb-3">Tỷ lệ công cộng đơn vị</h3>
        <%= hidden_field_tag "unit_config[lock_version]", @unit_config.lock_version %>
        <div class="flex items-center space-x-2">
          <%= number_field_tag "unit_config[unit_public_rate]", @unit_config.unit_public_rate,
              step: "0.01", disabled: !can_edit,
              class: "w-32 rounded border border-gray-300 px-3 py-2 text-sm text-right" %>
          <span class="text-sm text-gray-700">%</span>
        </div>
        <p class="text-xs text-gray-500 mt-2">Tỷ lệ trừ cho phần công cộng đơn vị (áp dụng cho mọi đầu mối sinh hoạt trong đơn vị).</p>
      </div>
    <% end %>

    <!-- Phần 2: other_deductions per CP (đơn vị) — chỉ khi có đơn vị -->
    <% if @unit %>
      <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden">
        <div class="p-4 border-b border-gray-200">
          <h3 class="text-base font-semibold text-gray-900">Cột "Khác" cho từng đầu mối sinh hoạt thuộc đơn vị</h3>
        </div>
        <% if @other_deductions.any? %>
          <%= render "unit_config/other_deductions_table", other_deductions: @other_deductions, can_edit: can_edit %>
        <% else %>
          <p class="px-4 py-3 text-sm text-gray-500">Chưa có đầu mối sinh hoạt nào trong đơn vị.</p>
        <% end %>
      </div>
    <% end %>

    <!-- Phần 3: other_deductions per CP (khu vực) -->
    <% if @zone_other_deductions.any? %>
      <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden">
        <div class="p-4 border-b border-gray-200">
          <h3 class="text-base font-semibold text-gray-900">Cột "Khác" cho từng đầu mối sinh hoạt thuộc khu vực</h3>
        </div>
        <%= render "unit_config/other_deductions_table", other_deductions: @zone_other_deductions, can_edit: can_edit %>
      </div>
    <% end %>

    <!-- Empty-state: SA chọn khu vực mà không có đầu mối zone-direct -->
    <% if @unit.nil? && @zone && @zone_other_deductions.empty? %>
      <p class="bg-gray-50 border border-gray-200 rounded p-3 text-sm text-gray-600"><%= t("unit_config.zone_context.empty") %></p>
    <% end %>

    <% if can_edit && (@unit || @zone_other_deductions.any?) %>
      <div class="flex space-x-2">
        <%= submit_tag "Lưu cấu hình",
            class: "bg-blue-600 text-white px-4 py-2 rounded text-sm font-medium hover:bg-blue-700 cursor-pointer" %>
      </div>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 5: Thêm khoá i18n empty-state**

Trong `config/locales/vi.yml`, dưới khối `unit_config:` (namespace view, khoảng dòng 436, nơi có `flash:` và `other_deductions:`), thêm:

```yaml
    zone_context:
      empty: "Chọn đơn vị để xem cấu hình đơn vị, hoặc khu vực này chưa có đầu mối thuộc khu vực."
```

Đặt cùng cấp với `flash:` và `other_deductions:` (thụt 6 space dưới `unit_config:`).

- [ ] **Step 6: Chạy test, xác nhận PASS**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "CHIEU-khac-zone-direct-orphan"`
Expected: PASS.

- [ ] **Step 7: Chạy lại toàn bộ request spec của trang để không vỡ hành vi cũ**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb`
Expected: PASS toàn bộ (các test role/dropdown cũ không đổi vì đường `@unit` giữ nguyên).

- [ ] **Step 8: Commit**

```bash
git add app/controllers/unit_config_controller.rb app/views/unit_config/show.html.erb config/locales/vi.yml spec/requests/unit_config_spec.rb
git commit -m "feat: surface zone-direct other-deductions in zone context (#328)"
```

---

## Task 2: PATCH — cập nhật "Khác" đầu mối zone-direct theo ngữ cảnh khu vực

**Files:**
- Test: `spec/requests/unit_config_spec.rb`
- Modify: `app/controllers/unit_config_controller.rb`

- [ ] **Step 1: Viết test thất bại (PATCH zone-context lưu giá trị)**

Thêm vào trong `describe "system_admin sửa 'Khác' ... (#328)"` (đã tạo ở Task 1), sau test orphan:

```ruby
    it "CHIEU-khac-zone-direct-sua-duoc: PATCH zone-context cập nhật 'Khác' của đầu mối zone-direct (BigDecimal)" do
      od = OtherDeduction.find_by!(contact_point: orphan_zone_cp, period: period)

      patch unit_config_path, params: {
        zone_id: orphan_zone.id,
        other_deductions: {
          od.id.to_s => { other_type: "fixed", other_value: "12.34", lock_version: od.lock_version }
        }
      }

      expect(response).to redirect_to(unit_config_path(zone_id: orphan_zone.id))
      expect(od.reload.other_value).to eq(BigDecimal("12.34"))
      expect(od.reload.other_type).to eq("fixed")
    end
```

- [ ] **Step 2: Chạy test, xác nhận FAIL**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "CHIEU-khac-zone-direct-sua-duoc"`
Expected: FAIL — `#update` không set `@zone` (scope zone-direct rỗng → OD không nằm trong `all_editable_ods` → không cập nhật; redirect sai về `unit_id: nil`).

- [ ] **Step 3: Sửa `#update` — thêm nhánh zone-context**

Trong `app/controllers/unit_config_controller.rb`, thay method `update` (dòng 23-68) bằng:

```ruby
  def update
    @unit = resolve_unit_for_update
    @zone = resolve_zone_for_update
    @period = current_period
    @unit_config = find_or_create_unit_config
    if @unit_config
      authorize!(:update, @unit_config)
    elsif @unit
      authorize!(:update, UnitConfig.new(unit: @unit, period: @period))
    else
      # Ngữ cảnh khu vực (SA, không có @unit): chỉ sửa OtherDeduction zone-direct.
      authorize!(:update, OtherDeduction)
    end

    errors_collected = []
    ActiveRecord::Base.transaction do
      if @unit_config && params[:unit_config].present?
        attrs = params.require(:unit_config).permit(:unit_public_rate, :lock_version)
        unless @unit_config.update(attrs)
          errors_collected << { name: "Cấu hình đơn vị", msgs: @unit_config.errors.full_messages }
        end
      end

      all_editable_ods = @unit ? scope_other_deductions.or(scope_zone_other_deductions) : scope_zone_other_deductions
      (params[:other_deductions] || {}).each do |id, attrs|
        od = all_editable_ods.find_by(id: id)
        next unless od
        authorize!(:update, od)
        permitted = attrs.permit(:other_type, :other_value, :lock_version)
        unless od.update(permitted)
          errors_collected << { name: od.contact_point.name, msgs: od.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors_collected.any?
    end

    if errors_collected.any?
      flash.now[:alert] = errors_collected.map { |e| "#{e[:name]}: #{e[:msgs].join(', ')}" }.join("\n")
      @unit_config = UnitConfig.find_by(unit: @unit, period: @period)
      @other_deductions = scope_other_deductions
      @zone_other_deductions = scope_zone_other_deductions
      # View show.html.erb đọc @available_zones/@available_units vô điều kiện cho SA → phải set lại khi re-render.
      # Giữ @zone đã resolve cho nhánh zone-context (||= để không clobber khi @unit nil).
      @zone ||= @unit&.zone if current_user.system_admin?
      set_sa_filter_dropdowns
      render :show, status: :unprocessable_content
    else
      redirect_to unit_config_path(@unit ? { unit_id: @unit.id } : { zone_id: @zone&.id }),
                  notice: t("unit_config.flash.saved")
    end
  end
```

- [ ] **Step 4: Thêm `resolve_zone_for_update`**

Trong cùng file, ngay sau method `resolve_unit_for_update` (kết thúc khoảng dòng 100), thêm:

```ruby
  # Ngữ cảnh khu vực cho #update: chỉ SA, khi không chọn đơn vị mà có zone_id.
  # Tôn trọng reopened_old_period? như đường unit (với_discarded khi xem kỳ cũ mở lại).
  def resolve_zone_for_update
    return nil unless current_user.system_admin? && @unit.nil? && params[:zone_id].present?
    zone_scope = reopened_old_period? ? Zone.with_discarded : Zone.kept
    zone_scope.find(params[:zone_id])
  end
```

- [ ] **Step 5: Chạy test, xác nhận PASS**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "CHIEU-khac-zone-direct-sua-duoc"`
Expected: PASS.

- [ ] **Step 6: Chạy lại toàn bộ request spec**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb`
Expected: PASS toàn bộ (đường `@unit` dùng `scope_other_deductions.or(scope_zone_other_deductions)` y như cũ).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/unit_config_controller.rb spec/requests/unit_config_spec.rb
git commit -m "feat: allow zone-context PATCH for zone-direct other-deductions (#328)"
```

---

## Task 3: Phân quyền ngữ cảnh khu vực — sáu vai trò + empty-state (request)

**Files:**
- Test: `spec/requests/unit_config_spec.rb`

- [ ] **Step 1: Viết test thất bại (vai trò + empty-state)**

Thêm vào trong `describe "system_admin sửa 'Khác' ... (#328)"`, sau test sua-duoc:

```ruby
    it "CHIEU-khac-zone-direct-trang-trong: chọn khu vực không có đầu mối zone-direct → hiện gợi ý" do
      empty_zone = create(:zone, name: "Khu vực rỗng")
      get unit_config_path(zone_id: empty_zone.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("unit_config.zone_context.empty"))
    end

    it "CHIEU-khac-zone-direct-vai-tro: chỉ system_admin vào được ngữ cảnh khu vực orphan; non-SA không thấy" do
      html = ->(body) { Nokogiri::HTML(body) }

      # system_admin: thấy đầu mối + input không disabled (sửa được).
      get unit_config_path(zone_id: orphan_zone.id)
      expect(response.body).to include("Zone-CP-Orphan")
      html.call(response.body).css("input[type='number'], select").each do |input|
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
```

- [ ] **Step 2: Chạy test, xác nhận trạng thái**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "CHIEU-khac-zone-direct-trang-trong" -e "CHIEU-khac-zone-direct-vai-tro"`
Expected: PASS (logic đã có từ Task 1-2; đây là test bổ sung phủ chiều vai trò + empty-state). Nếu FAIL ở empty-state → kiểm tra khoá i18n Task 1 Step 5. Nếu FAIL ở technician → xác nhận `BusinessRoleRequired` áp cho action `show` (đọc concern; technician không thuộc 4 vai trò nghiệp vụ).

> Ghi chú: vai trò manager (unit_admin/commander quản lý khu vực) đã được phủ ở các context `as unit_admin (zone-manager)` / `as commander (zone-manager)` sẵn có trong file — đường manager-unit không đổi. Test này phủ phần MỚI (ngữ cảnh khu vực = SA-only).

- [ ] **Step 3: Commit**

```bash
git add spec/requests/unit_config_spec.rb
git commit -m "test: cover roles and empty-state for zone-context other-deductions (#328)"
```

---

## Task 4: System spec — đường người dùng bấm dropdown khu vực

**Files:**
- Test: `spec/system/unit_config_spec.rb`

- [ ] **Step 1: Viết test thất bại (system, trong context `as system_admin`)**

Trong `spec/system/unit_config_spec.rb`, trong block `context "as system_admin"`, thêm 2 `it` (cần `rank` + đầu mối zone-direct nên khai `let!` cục bộ trong context — đặt cạnh các `let` hiện có của context này):

```ruby
    let!(:rank_for_zone_cp) { create(:rank, period: period, name: "R1", position: 1) }
    let!(:zone1_direct_cp) {
      create(:contact_point, :zone_residential, zone: zone1, name: "Zone-CP-Alpha",
             initial_personnel_counts: { rank_for_zone_cp.id => 1 })
    }

    it "CHIEU-khac-zone-direct-sua-duoc: chọn khu vực (không chọn đơn vị) → hiện bảng sửa 'Khác' thuộc khu vực" do
      visit unit_config_path(zone_id: zone1.id)
      expect(page).to have_content("thuộc khu vực")
      expect(page).to have_content("Zone-CP-Alpha")
      expect(page).to have_button("Lưu cấu hình")
    end

    it "CHIEU-khac-zone-direct-trang-trong: chọn khu vực không có đầu mối zone-direct → hiện gợi ý" do
      visit unit_config_path(zone_id: zone2.id)
      expect(page).to have_content(I18n.t("unit_config.zone_context.empty"))
    end
```

> `zone1` có `unit1` (auto-manager) nhưng ta chọn zone **không** chọn unit → ngữ cảnh khu vực always-on vẫn hiện `Zone-CP-Alpha`. `zone2` có `unit2` nhưng không có đầu mối zone-direct → empty-state.

- [ ] **Step 2: Chạy test, xác nhận PASS**

Run: `bin/docker rspec spec/system/unit_config_spec.rb -e "CHIEU-khac-zone-direct"`
Expected: PASS. (Logic đã có; system test xác nhận đường bấm thật + headless Chrome render.)

- [ ] **Step 3: Chạy lại toàn bộ system spec của trang**

Run: `bin/docker rspec spec/system/unit_config_spec.rb`
Expected: PASS toàn bộ. Lưu ý test cũ `"chưa chọn đơn vị → không hiện form cấu hình"` (visit `unit_config_path` KHÔNG có zone_id) vẫn đúng: không `@unit` và không `@zone` → form không render.

- [ ] **Step 4: Commit**

```bash
git add spec/system/unit_config_spec.rb
git commit -m "test: system spec for zone-context other-deduction editing (#328)"
```

---

## Task 5: Glossary "probe" + bump version THUAT_NGU

**Files:**
- Modify: `docs/THUAT_NGU.md`

- [ ] **Step 1: Đọc cấu trúc §3 và header version**

Run: `grep -n "Phiên bản:\|## 3\|Gloss\|## Lịch sử thay đổi\|fan-out\|fan_out" docs/THUAT_NGU.md | head -30`
Mục tiêu: xác định (a) dòng `Phiên bản:` ở đầu file, (b) vị trí §3 (Gloss khái niệm), (c) cách entry hiện có được format (vd "fan-out"), (d) đầu mục `## Lịch sử thay đổi`.

- [ ] **Step 2: Thêm định nghĩa "probe" vào §3 (Gloss khái niệm)**

Thêm một entry "probe" theo đúng format các entry gloss hiện có trong §3 (đặt theo thứ tự hợp lý của mục — alphabetical nếu mục đang sắp xếp vậy, hoặc cuối mục nếu không). Nội dung định nghĩa:

> **probe** (thăm dò): đoạn mã hoặc kiểm thử chạy thử để **xác minh hành vi** của hệ thống rồi **rollback** (không để lại dữ liệu) — ví dụ chạy trong một transaction rồi `raise ActiveRecord::Rollback`. Dùng để kiểm chứng giả thuyết về hành vi mà không thay đổi trạng thái thật. Xuất hiện trong bản ghi Issue #328.

(Khớp văn phong entry hiện có: nếu các entry khác không in đậm tên hoặc dùng dấu khác, theo đúng kiểu đó.)

- [ ] **Step 3: Bump version + thêm changelog (ADR-002)**

- Tăng `Phiên bản:` ở đầu `docs/THUAT_NGU.md` lên mức kế tiếp (vd nếu đang `1.3.0` → `1.4.0` cho việc thêm thuật ngữ mới; theo tiền lệ "fan-out" đã bump minor — căn theo mức bump tiền lệ trong chính file).
- Thêm entry mới ở đầu `## Lịch sử thay đổi`, theo format các entry hiện có, ví dụ:

```markdown
### <version> (2026-06-13)

- Thêm gloss "probe" (thăm dò) vào §3 — đoạn mã/test chạy thử rồi rollback để xác minh hành vi (theo comment Issue #328, nguyên tắc glossary ADR-023/024).
```

- [ ] **Step 4: Verify guardrail glossary không đỏ**

Run: `bash .github/scripts/check-glossary.sh 2>&1 | tail -5` (nếu tên script khác, tìm bằng `ls .github/scripts/ | grep -i gloss`).
Expected: xanh (exit 0). Nếu script dùng perl mojibake → chạy với `perl -Mutf8` theo gotcha đã biết.

- [ ] **Step 5: Commit**

```bash
git add docs/THUAT_NGU.md
git commit -m "docs: add 'probe' glossary term (#328)"
```

---

## Task 6: Verify toàn cục + guardrails trước khi mở PR

**Files:** (không sửa code; chạy kiểm tra)

- [ ] **Step 1: Guardrail truy vết chiều test (ADR-030)**

Run: `bash .github/scripts/check-test-dimensions.sh 2>&1 | tail -10`
Expected: xanh — cả 4 anchor `CHIEU-khac-zone-direct-{orphan,sua-duoc,vai-tro,trang-trong}` đều có ≥1 test mang anchor (đã thêm ở Task 1-4) và không trùng spec khác.

- [ ] **Step 2: Guardrail i18n view (ADR-032)**

Run: `bash .github/scripts/check-view-i18n.sh 2>&1 | tail -10`
Expected: xanh — chuỗi mới duy nhất (`unit_config.zone_context.empty`) đi qua `t(...)`; markup tiếng Việt hard-code (heading, "Lưu cấu hình") trùng baseline sẵn có (dedup theo text → không phát sinh dòng mới).

- [ ] **Step 3: Chạy toàn bộ spec của trang (request + system + model)**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb spec/system/unit_config_spec.rb spec/models/unit_config_spec.rb`
Expected: PASS toàn bộ.

- [ ] **Step 4: (tùy thời gian) Chạy full suite cục bộ**

Run: `bin/docker rspec`
Expected: PASS. (Nếu quá lâu — quy ước lệnh >2 phút — cân nhắc chạy nhóm liên quan, để CI chạy full trên PR.)

---

## Notes / Self-Review

**Spec coverage:**
- ADR-034 quyết định (decouple, always-on zone surfacing, giữ manager path, không hard-block) → Task 1 (scope/show) + Task 2 (update) + Task 4 (UI).
- i18n ADR-032 → Task 1 Step 5 + Task 6 Step 2.
- Glossary "probe" → Task 5.
- Bảng Truy vết chiều test (4 anchor) → Task 1 (orphan), Task 2 (sua-duoc), Task 3 (vai-tro + trang-trong request), Task 4 (sua-duoc + trang-trong system). Guardrail verify ở Task 6 Step 1.
- Ngoài scope (không hard-block manager, không đụng billing, không kỳ-đóng-editable) → không có task; `require_open_period` đã guard `#update`.

**Type/method consistency:**
- Method mới: `zone_other_deduction_zone_ids`, `resolve_zone_for_update` (controller). Dùng nhất quán ở `scope_zone_other_deductions` và `#update`.
- `all_editable_ods`: nhánh `@unit` giữ `scope_other_deductions.or(scope_zone_other_deductions)` (đường cũ, đã có test pass); nhánh zone-context dùng `scope_zone_other_deductions` đơn lẻ (tránh `none.or(real)`).
- i18n key thống nhất: `unit_config.zone_context.empty` (view + 3 test).

**Placeholder scan:** không có TBD/TODO; mọi step có code/lệnh cụ thể.
