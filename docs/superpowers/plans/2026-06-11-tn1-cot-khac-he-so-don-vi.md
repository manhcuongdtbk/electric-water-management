# TN1 — Cột "Khác" dạng hệ số (đơn vị) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm cách nhập thứ ba `unit_coefficient` cho khoản trừ "Khác": khoản trừ = `hệ số × (tổng quân số residential đơn vị − quân số đầu mối đó)`.

**Architecture:** Mở rộng enum `OtherDeduction#other_type` (lưu chuỗi, không migration), thêm một nhánh tính trong `SummaryCalculator` (gom tổng quân số residential theo đơn vị từ dữ liệu đã preload), validate mode mới chỉ cho đầu mối thuộc đơn vị, và thêm option vào select trên trang Cấu hình đơn vị (ẩn cho đầu mối thuộc khu vực trực tiếp).

**Tech Stack:** Rails 8, RSpec, FactoryBot, i18n (vi.yml), Hotwire view (ERB). Chạy test: `bin/docker rspec`.

**Nguồn:** spec [`docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md`](../specs/2026-06-11-cot-khac-he-so-don-vi-design.md) (ADR-025); nghiệp vụ `V2_XAC_NHAN_NGHIEP_VU.md` anchor `NV-cot-khac-he-so-don-vi`.

**Không có migration** — `other_type` là cột chuỗi; thêm value enum không đổi schema.

---

## File Structure

- Modify `app/models/other_deduction.rb` — thêm enum value + validation `unit_coefficient` chỉ cho CP có đơn vị.
- Modify `config/locales/vi.yml` — message lỗi validation.
- Modify `app/services/summary_calculator.rb` — preload tổng quân số đơn vị + nhánh tính `unit_coefficient`.
- Modify `app/views/unit_config/_other_deductions_table.html.erb` — option select theo từng dòng (ẩn cho CP zone-direct).
- Test: `spec/models/other_deduction_spec.rb`, `spec/services/summary_calculator_spec.rb`, `spec/requests/unit_config_spec.rb`.

---

## Task 1: Model — enum value + validation + i18n

**Files:**
- Modify: `app/models/other_deduction.rb`
- Modify: `config/locales/vi.yml` (dưới `vi.activerecord.errors.models`)
- Test: `spec/models/other_deduction_spec.rb`

- [ ] **Step 1: Write failing tests**

Thêm vào `spec/models/other_deduction_spec.rb`, trong block `describe "enum :other_type"` đổi assertion danh sách và thêm context validation mới ở cuối file (trước `end` cuối):

```ruby
  describe "enum :other_type" do
    it "có giá trị fixed, coefficient và unit_coefficient" do
      expect(OtherDeduction.other_types.keys).to match_array(%w[fixed coefficient unit_coefficient])
    end

    it "tạo method prefix :other" do
      record = build(:other_deduction, other_type: "fixed")
      expect(record.other_fixed?).to be true
      expect(record.other_coefficient?).to be false
      expect(record.other_unit_coefficient?).to be false
    end
  end

  describe "unit_coefficient chỉ cho đầu mối thuộc đơn vị" do
    it "valid khi đầu mối thuộc đơn vị" do
      cp = create(:contact_point, :residential) # factory mặc định có unit
      record = build(:other_deduction, contact_point: cp, other_type: "unit_coefficient", other_value: -2)
      expect(record).to be_valid
    end

    it "invalid khi đầu mối thuộc khu vực trực tiếp (unit_id null)" do
      cp = create(:contact_point, :zone_residential)
      record = build(:other_deduction, contact_point: cp, other_type: "unit_coefficient", other_value: -2)
      expect(record).not_to be_valid
      expect(record.errors[:other_type]).to be_present
    end

    it "fixed/coefficient vẫn valid cho đầu mối khu vực trực tiếp" do
      cp = create(:contact_point, :zone_residential)
      record = build(:other_deduction, contact_point: cp, other_type: "coefficient", other_value: 2)
      expect(record).to be_valid
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/docker rspec spec/models/other_deduction_spec.rb`
Expected: FAIL — `unit_coefficient` chưa là enum value; `other_unit_coefficient?` chưa tồn tại; validation chưa có.

- [ ] **Step 3: Add enum value + validation in model**

`app/models/other_deduction.rb` — đổi dòng enum và thêm validation:

```ruby
class OtherDeduction < ApplicationRecord
  include Auditable

  enum :other_type, { fixed: "fixed", coefficient: "coefficient", unit_coefficient: "unit_coefficient" },
    prefix: :other

  belongs_to :contact_point
  belongs_to :period

  validates :other_type, presence: true
  validates :other_value, presence: true, numericality: true
  validates :contact_point_id, uniqueness: { scope: :period_id }
  validate :unit_coefficient_requires_unit

  private

  def unit_coefficient_requires_unit
    return unless other_unit_coefficient?
    errors.add(:other_type, :unit_coefficient_requires_unit) if contact_point&.unit_id.nil?
  end
end
```

- [ ] **Step 4: Add i18n message**

`config/locales/vi.yml` — dưới `vi.activerecord.errors.models`, thêm block `other_deduction` (cùng cấp với `contact_point`, `unit`, `meter`...):

```yaml
        other_deduction:
          attributes:
            other_type:
              unit_coefficient_requires_unit: "Cách nhập \"Theo hệ số (đơn vị)\" chỉ dùng cho đầu mối thuộc đơn vị"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/docker rspec spec/models/other_deduction_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/other_deduction.rb config/locales/vi.yml spec/models/other_deduction_spec.rb
git commit -m "feat(other-deduction): add unit_coefficient input mode with unit guard"
```

---

## Task 2: SummaryCalculator — nhánh tính unit_coefficient

**Files:**
- Modify: `app/services/summary_calculator.rb`
- Test: `spec/services/summary_calculator_spec.rb`

Bối cảnh dữ liệu: `setup_zone_one_full_sample` tạo Đơn vị A với 3 đầu mối residential — ban_tac_huan (5 người), van_thu (2 người), kho_vat_tu (3 người) → **tổng residential Đơn vị A = 10**. `chi_huy_khu_vuc` là đầu mối thuộc khu vực (unit_id null), không tính vào tổng đơn vị.

- [ ] **Step 1: Write failing test**

Thêm vào `spec/services/summary_calculator_spec.rb`, bên trong `describe "#call — T03 (dữ liệu mẫu mục 1)"` (dùng lại `sample`, `loss_results`, `pump_results`, `result`, `calculation_for` đã có), một describe mới:

```ruby
    describe "Văn thư (Đơn vị A) — cột Khác hệ số (đơn vị)" do
      before do
        apply_other_deduction(sample.contact_points[:van_thu], sample.period,
                              type: "unit_coefficient", value: -2)
        # tính lại sau khi đổi cấu hình
        described_class.new(zone: sample.zone, period: sample.period,
                            loss_results: loss_results, pump_results: pump_results).call
      end

      it "khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối)" do
        # -2 × (10 − 2) = -16
        calc = calculation_for(:van_thu)
        expect(calc.other_deduction).to eq_display("-16.00")
      end
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/docker rspec spec/services/summary_calculator_spec.rb -e "cột Khác hệ số (đơn vị)"`
Expected: FAIL — nhánh `unit_coefficient` chưa có nên rơi vào `else` → 0, không bằng -16.00.

- [ ] **Step 3: Implement unit-total preload + branch**

`app/services/summary_calculator.rb`:

(a) Trong `call`, sau dòng `@personnel_by_cp_id = preload_personnel_entries(residentials)`, thêm:

```ruby
    @unit_total_personnel_by_unit_id = preload_unit_total_personnel(residentials)
```

(b) Thêm method preload (đặt cạnh các `preload_*` khác):

```ruby
  def preload_unit_total_personnel(residentials)
    totals = Hash.new(0)
    residentials.each do |cp|
      next if cp.unit_id.nil?
      entries = @personnel_by_cp_id[cp.id] || []
      totals[cp.unit_id] += entries.sum(&:count)
    end
    totals
  end
```

(c) Sửa `compute_other_deduction` thêm nhánh `when "unit_coefficient"`:

```ruby
  def compute_other_deduction(contact_point, total_personnel)
    deduction = @other_deductions_by_cp_id[contact_point.id]
    return BigDecimal("0") if deduction.nil?

    case deduction.other_type
    when "fixed"
      BigDecimal(deduction.other_value.to_s)
    when "coefficient"
      BigDecimal(deduction.other_value.to_s) * BigDecimal(total_personnel.to_s)
    when "unit_coefficient"
      return BigDecimal("0") if contact_point.unit_id.nil?
      unit_total = @unit_total_personnel_by_unit_id[contact_point.unit_id] || 0
      BigDecimal(deduction.other_value.to_s) * BigDecimal((unit_total - total_personnel).to_s)
    else
      BigDecimal("0")
    end
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/docker rspec spec/services/summary_calculator_spec.rb -e "cột Khác hệ số (đơn vị)"`
Expected: PASS.

- [ ] **Step 5: Run full service spec (no regression)**

Run: `bin/docker rspec spec/services/summary_calculator_spec.rb`
Expected: PASS toàn bộ.

- [ ] **Step 6: Commit**

```bash
git add app/services/summary_calculator.rb spec/services/summary_calculator_spec.rb
git commit -m "feat(summary): compute unit_coefficient other-deduction from unit headcount"
```

---

## Task 3: View + request — option select theo loại đầu mối

**Files:**
- Modify: `app/views/unit_config/_other_deductions_table.html.erb`
- Test: `spec/requests/unit_config_spec.rb`

- [ ] **Step 1: Write failing request tests**

Thêm vào `spec/requests/unit_config_spec.rb` một describe mới (dùng pattern đăng nhập + dữ liệu như các test khác trong file; đọc đầu file để tái dùng helper login và setup hiện có):

```ruby
  describe "cột Khác — cách nhập unit_coefficient" do
    let(:sample) { setup_zone_one_full_sample }

    before { sign_in_system_admin } # dùng helper login sẵn có trong file

    it "đầu mối thuộc đơn vị: select có option unit_coefficient" do
      get unit_config_path(unit_id: sample.unit_a.id)
      expect(response.body).to include('value="unit_coefficient"')
    end

    it "đầu mối thuộc khu vực trực tiếp: select KHÔNG có option unit_coefficient" do
      # @zone_other_deductions = đầu mối residential zone-direct của khu vực Đơn vị A quản lý
      get unit_config_path(unit_id: sample.unit_a.id)
      zone_section = response.body[/Phần 3.*/m] || response.body
      # chi_huy_khu_vuc là đầu mối zone-direct; chỉ kiểm tra option chỉ xuất hiện ở phần đơn vị
      expect(response.body.scan('value="unit_coefficient"').size).to eq(sample_unit_a_residential_count)
    end

    it "server từ chối unit_coefficient cho đầu mối khu vực trực tiếp" do
      od = OtherDeduction.find_by(contact_point: sample.contact_points[:chi_huy_khu_vuc], period: sample.period)
      patch unit_config_path,
            params: { unit_id: sample.unit_a.id,
                      other_deductions: { od.id.to_s => { other_type: "unit_coefficient", other_value: "-2", lock_version: od.lock_version } } }
      expect(od.reload.other_type).not_to eq("unit_coefficient")
    end

    it "server chấp nhận unit_coefficient cho đầu mối thuộc đơn vị" do
      od = OtherDeduction.find_by(contact_point: sample.contact_points[:van_thu], period: sample.period)
      patch unit_config_path,
            params: { unit_id: sample.unit_a.id,
                      other_deductions: { od.id.to_s => { other_type: "unit_coefficient", other_value: "-2", lock_version: od.lock_version } } }
      expect(od.reload.other_type).to eq("unit_coefficient")
    end
  end
```

> Lưu ý cho người thực thi: đọc `spec/requests/unit_config_spec.rb` đầu file để dùng đúng tên helper đăng nhập (ví dụ `sign_in` + factory user system_admin) và bỏ `sample_unit_a_residential_count` nếu khó xác định — thay bằng assertion đơn giản: phần đơn vị có option, và `response.body` ở khối "Phần 3" (khu vực) không chứa `unit_coefficient`. Mục tiêu: option chỉ hiện cho đầu mối thuộc đơn vị.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "cách nhập unit_coefficient"`
Expected: FAIL — partial chưa có option `unit_coefficient`; (test server-reject sẽ pass sẵn nhờ validation Task 1, nhưng test "có option" sẽ fail).

- [ ] **Step 3: Make select options conditional per row**

`app/views/unit_config/_other_deductions_table.html.erb` — thay khối `select_tag`:

```erb
        <td class="px-4 py-2 text-sm">
          <%= hidden_field_tag "other_deductions[#{od.id}][lock_version]", od.lock_version %>
          <% type_options = od.contact_point.unit_id.present? ?
               [["Cố định", "fixed"], ["Theo hệ số", "coefficient"], ["Theo hệ số (đơn vị)", "unit_coefficient"]] :
               [["Cố định", "fixed"], ["Theo hệ số", "coefficient"]] %>
          <%= select_tag "other_deductions[#{od.id}][other_type]",
              options_for_select(type_options, od.other_type),
              disabled: !can_edit,
              class: "rounded border border-gray-300 px-2 py-1 text-sm" %>
        </td>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/docker rspec spec/requests/unit_config_spec.rb -e "cách nhập unit_coefficient"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/unit_config/_other_deductions_table.html.erb spec/requests/unit_config_spec.rb
git commit -m "feat(unit-config): offer unit_coefficient option only for unit contact points"
```

---

## Task 4: Full suite + push + PR

- [ ] **Step 1: Run full test suite**

Run: `bin/docker rspec`
Expected: PASS (gồm system spec, zeitwerk, schema không lệch).

- [ ] **Step 2: Push branch**

```bash
git push -u origin feature/1.2.0-tn1-cot-khac
```

- [ ] **Step 3: Open pull request (base develop)**

Tiêu đề: `feat: cột "Khác" dạng hệ số (đơn vị)` — base `develop`. Body: link spec ADR-025, anchor `NV-cot-khac-he-so-don-vi`, test plan (3 task TDD), ghi `Closes #319` chỉ khi đây là tính năng cuối của milestone (KHÔNG dùng "Closes" ở đây — #319 còn TN2/TN3). Theo dõi CI, báo kết quả.

---

## Self-Review (đã chạy)

- **Spec coverage:** enum value (Task 1), tính toán hệ số × (tổng đơn vị − đầu mối) gồm số âm (Task 2), validate chỉ cho đầu mối thuộc đơn vị (Task 1) + chặn server (Task 3), ẩn option cho zone-direct (Task 3), kế thừa kỳ (không cần code — đã kế thừa other_type/other_value sẵn; phủ bởi spec kế thừa hiện có). Quân số đổi tự tính lại = hệ quả tính live (Task 2), có thể thêm test nếu muốn nhưng cùng code path.
- **Placeholder scan:** không có TODO/“xử lý sau”. Một chú thích ở Task 3 nhắc người thực thi đọc helper login của file request spec (tên helper khác nhau giữa repo) — không phải placeholder code, mà là chỉ dẫn dùng hạ tầng test sẵn có.
- **Type consistency:** `other_unit_coefficient?`, enum key `unit_coefficient`, `@unit_total_personnel_by_unit_id`, method `preload_unit_total_personnel` — nhất quán giữa các task.
