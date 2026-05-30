# V2_KICH_BAN_TEST.md Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Viết lại toàn bộ `docs/V2_KICH_BAN_TEST.md` thành tài liệu kịch bản số liệu cụ thể (hybrid), golden numbers verify bằng engine thật, cover 6 vai trò + 6 nhóm giao điểm nguy hiểm + 18 trang, dựa trên 2 khu vực mẫu.

**Architecture:** Tổ chức theo tầng dữ liệu (6 phần): dữ liệu mẫu → golden numbers từ engine → giao điểm nguy hiểm → walkthrough trang × vai trò → vận hành → truy vết. Khu vực 1 khớp `setup_zone_one_full_sample`; thêm Khu vực 2 (helper additive) lấp các lỗ hổng KV1 không có. Golden numbers lấy từ `CalculationOrchestrator` chạy trong test env (FactoryBot + sample_data có sẵn ở đó).

**Tech Stack:** Rails 8, RSpec + FactoryBot, BigDecimal, Docker (`bin/docker rspec` / `bin/docker console`). Tài liệu Markdown tiếng Việt.

**Nguồn:** Spec thiết kế `docs/specs/2026-05-31-v2-kich-ban-test-rewrite-design.md` (đọc trước khi thực hiện).

---

## File Structure

| File | Trách nhiệm | Thao tác |
|---|---|---|
| `spec/support/sample_data.rb` | Helper dữ liệu mẫu. Thêm KV2, không sửa KV1 | Modify (additive) |
| `spec/tmp_golden_numbers_spec.rb` | Spec throwaway: build KV1+KV2, chạy orchestrator, in golden numbers | Create rồi **xóa** sau khi trích số |
| `docs/V2_KICH_BAN_TEST.md` | Deliverable — tài liệu kịch bản test viết lại | Overwrite toàn bộ |
| `app/services/**`, `spec/**` engine specs | Tham khảo (đọc) để lấy KV1 golden numbers + cách drive engine + traceability | Read-only |

**Quy ước chung khi thực hiện:**
- Mỗi lệnh chạy lâu (>2 phút) phải hỏi trước hoặc chia nhỏ. `bin/docker rspec <1 file>` thường nhanh — OK.
- Commit message tiếng Anh, kết bằng dòng `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Đang ở nhánh `claude/cranky-goldstine-4fb007` (không phải main) — commit trực tiếp được, không push tới khi được duyệt.

---

## Task 1: Khảo sát engine + factories + golden numbers KV1 (read-only)

**Files:**
- Read: `app/services/` (LossCalculator, PumpAllocationCalculator, SummaryCalculator, CalculationOrchestrator)
- Read: `spec/factories/` (zone, unit, contact_point + traits, meter, pump_allocation, main_meter, block, group, rank)
- Read: các engine spec dùng `setup_zone_one_full_sample` (để lấy KV1 golden numbers đã verify + cách gọi orchestrator)

- [ ] **Step 1: Xác định tên class + chữ ký gọi orchestrator**

Run: `grep -rl "CalculationOrchestrator\|class .*Calculator" app/services`
Expected: tìm thấy các file calculator + orchestrator. Ghi lại đường dẫn chính xác và cách khởi tạo (`CalculationOrchestrator.new(zone:, period:).call` hoặc tương đương — xác nhận chữ ký thật).

- [ ] **Step 2: Xác định nơi đã verify KV1 golden numbers**

Run: `grep -rln "setup_zone_one_full_sample\|CalculationOrchestrator" spec`
Expected: danh sách spec dùng sample data + chạy engine. Đọc các assertion calculations (loss, pump, summary) — đây là KV1 golden numbers đã được test xác nhận (đối chiếu với T01–T04 file cũ).

- [ ] **Step 3: Xác nhận các trait factory cho KV2**

Run: `grep -rn "trait\|factory :" spec/factories/contact_points.rb spec/factories/pump_allocations.rb`
Expected: xác nhận tồn tại trait `:residential`, `:public_type`, `:water_pump`, `:non_establishment`, `:zone_residential`, và cách `initial_personnel_counts` được dùng. Xác nhận factory `:pump_allocation` nhận `zone/period/unit/contact_point/fixed_percentage/coefficient`.

- [ ] **Step 4: Ghi chú khảo sát (scratchpad, không commit)**

Tổng hợp: đường dẫn engine, chữ ký orchestrator, KV1 golden numbers (loss A/B/C + per-meter, pump D + per-target, summary per-CP + totals), tên trait/factory dùng cho KV2. Dùng cho các task sau.

---

## Task 2: Thêm helper `setup_zone_two_full_sample(period:)` vào sample_data.rb

**Files:**
- Modify: `spec/support/sample_data.rb` (thêm constant + public method + private builders; KHÔNG sửa `setup_zone_one_full_sample`)
- Test: `spec/tmp_golden_numbers_spec.rb` (tạm, dùng để chạy)

- [ ] **Step 1: Viết spec tạm khẳng định helper build được KV2 + orchestrator chạy không lỗi**

Tạo `spec/tmp_golden_numbers_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Golden numbers (tạm)", type: :model do
  include SampleData

  it "builds KV1 + KV2 trong cùng kỳ và chạy orchestrator" do
    s1 = setup_zone_one_full_sample            # mở kỳ 5/2026, build KV1
    s2 = setup_zone_two_full_sample(period: s1.period)  # build KV2 vào cùng kỳ

    expect(Zone.kept.count).to eq(2)
    expect(Period.where(closed: false).count).to eq(1)  # ràng buộc 1 kỳ mở

    [s1.zone, s2.zone].each do |zone|
      expect {
        CalculationOrchestrator.new(zone: zone, period: s1.period).call
      }.not_to raise_error
    end
  end
end
```

(Điều chỉnh tên/chữ ký orchestrator theo Task 1 Step 1 nếu khác.)

- [ ] **Step 2: Chạy spec để xác nhận FAIL (helper chưa tồn tại)**

Run: `bin/docker rspec spec/tmp_golden_numbers_spec.rb`
Expected: FAIL — `NoMethodError: undefined method 'setup_zone_two_full_sample'`.

- [ ] **Step 3: Thêm helper KV2 vào `spec/support/sample_data.rb`**

Thêm constant quân số KV2 (cạnh `SAMPLE_PERSONNEL`):

```ruby
    SAMPLE_PERSONNEL_KV2 = {
      quan_y:            { chi_huy_dai_doi: 1, ha_si_quan: 4 },   # 5 người
      trinh_sat:         { tieu_doan_dai_doi: 2, ha_si_quan: 6 }, # 8 người
      chi_huy_khu_vuc_2: { chi_huy_trung_doan: 1 }                # 1 người
    }.freeze

    SAMPLE_METER_READINGS_KV2 = {
      ct_qy:    { start: 0,     finish: 300,   no_loss: false },
      ct_ts:    { start: 1_000, finish: 1_500, no_loss: false },
      ct_chkv2: { start: 200,   finish: 700,   no_loss: false },
      ct_cc_c:  { start: 0,     finish: 180,   no_loss: false }
    }.freeze
```

Thêm public method (sau `setup_zone_one_full_sample`):

```ruby
  # Build Khu vực 2 vào period đã mở (do setup_zone_one_full_sample tạo).
  # Bổ sung cho dữ liệu mẫu KV1, chỉ thêm các lỗ hổng KV1 chưa có.
  def setup_zone_two_full_sample(period:)
    zone = create(:zone, name: "Khu vực 2")
    main_meter = create(:main_meter, name: "CT-Tổng-KV2", zone: zone)

    unit_c = create(:unit, name: "Đơn vị C", zone: zone)
    unit_d = create(:unit, name: "Đơn vị D", zone: zone)
    zone.update!(manager_unit: unit_c)

    ranks = build_sample_ranks_lookup(period)

    group_quan_y = create(:group, name: "Tổ Quân y", unit: unit_c, block: nil)

    contact_points = {
      quan_y: create_residential_with_personnel_kv2(
        name: "Quân y", unit: unit_c, group: group_quan_y,
        ranks: ranks, counts_key: :quan_y
      ),
      trinh_sat: create_residential_with_personnel_kv2(
        name: "Trinh sát", unit: unit_d,
        ranks: ranks, counts_key: :trinh_sat
      ),
      chi_huy_khu_vuc_2: create_zone_residential_with_personnel_kv2(
        name: "Chỉ huy khu vực 2", zone: zone,
        ranks: ranks, counts_key: :chi_huy_khu_vuc_2
      ),
      nha_an_2:   create(:contact_point, :public_type, name: "Nhà ăn 2", unit: unit_c),
      tram_bom_2: create(:contact_point, :water_pump, name: "Trạm bơm 2", zone: zone)
    }

    meters = {
      ct_qy:    create(:meter, name: "CT-QY",    contact_point: contact_points[:quan_y],            no_loss: false),
      ct_ts:    create(:meter, name: "CT-TS",    contact_point: contact_points[:trinh_sat],         no_loss: false),
      ct_chkv2: create(:meter, name: "CT-CHKV2", contact_point: contact_points[:chi_huy_khu_vuc_2], no_loss: false),
      ct_cc_c:  create(:meter, name: "CT-CC-C",  contact_point: contact_points[:nha_an_2],           no_loss: false),
      ct_bn2:   create(:meter, name: "CT-BN2",   contact_point: contact_points[:tram_bom_2],         no_loss: false)
    }

    SAMPLE_METER_READINGS_KV2.each do |meter_key, attrs|
      reading = meters[meter_key].meter_readings.find_by!(period: period)
      reading.update!(reading_start: BigDecimal(attrs[:start].to_s),
                      reading_end: BigDecimal(attrs[:finish].to_s),
                      no_loss: attrs[:no_loss])
    end
    # Công tơ bơm nước CT-BN2: nhập chỉ số riêng (sử dụng = 400)
    bn2 = meters[:ct_bn2].meter_readings.find_by!(period: period)
    bn2.update!(reading_start: BigDecimal("0"), reading_end: BigDecimal("400"), no_loss: false)

    main_meter_reading = main_meter.main_meter_readings.create!(period: period, usage: BigDecimal("3000"))

    unit_c.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("5"))
    unit_d.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("0"))

    apply_other_deduction(contact_points[:quan_y],            period, type: "fixed",       value: BigDecimal("0"))
    apply_other_deduction(contact_points[:trinh_sat],         period, type: "fixed",       value: BigDecimal("0"))
    apply_other_deduction(contact_points[:chi_huy_khu_vuc_2], period, type: "fixed",       value: BigDecimal("0"))

    # Phân bổ bơm nước KV2: thuần hệ số, KHÔNG có % cố định (khác KV1)
    pump_allocations = {
      unit_c: create(:pump_allocation, zone: zone, period: period, unit: unit_c, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      unit_d: create(:pump_allocation, zone: zone, period: period, unit: unit_d, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      chi_huy_khu_vuc_2: create(:pump_allocation, zone: zone, period: period, unit: nil,
                                contact_point: contact_points[:chi_huy_khu_vuc_2],
                                fixed_percentage: nil, coefficient: BigDecimal("1"))
    }

    OpenStruct.new(
      zone: zone, main_meter: main_meter, main_meter_reading: main_meter_reading,
      unit_c: unit_c, unit_d: unit_d,
      period: period, contact_points: contact_points, meters: meters,
      pump_allocations: pump_allocations
    )
  end
```

Thêm private builders (cạnh các builder KV1 hiện có):

```ruby
  def create_residential_with_personnel_kv2(name:, unit:, ranks:, counts_key:, block: nil, group: nil)
    counts = SAMPLE_PERSONNEL_KV2.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    create(:contact_point, :residential,
           name: name, unit: unit, block: block, group: group,
           initial_personnel_counts: initial)
  end

  def create_zone_residential_with_personnel_kv2(name:, zone:, ranks:, counts_key:)
    counts = SAMPLE_PERSONNEL_KV2.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    create(:contact_point, :zone_residential,
           name: name, zone: zone,
           initial_personnel_counts: initial)
  end
```

(Lưu ý: dùng lại `build_sample_ranks_lookup`, `apply_other_deduction` private có sẵn. Nếu `create_residential_with_personnel` KV1 đã đủ tổng quát, có thể tái dùng thay vì tạo `_kv2` — quyết định khi thực hiện, ưu tiên DRY nếu chữ ký khớp.)

- [ ] **Step 4: Chạy lại spec tạm để xác nhận PASS**

Run: `bin/docker rspec spec/tmp_golden_numbers_spec.rb`
Expected: PASS — 2 zones, 1 kỳ mở, orchestrator chạy không lỗi cho cả 2 zone.

- [ ] **Step 5: Commit helper (chưa commit spec tạm)**

```bash
git add spec/support/sample_data.rb
git commit -m "$(printf 'Add setup_zone_two_full_sample test helper\n\nAdditive Khu vuc 2 sample builder sharing the open period created by\nsetup_zone_one_full_sample. Fills gaps Khu vuc 1 lacks (hierarchy\nposition 3, cross-zone, pure-coefficient pump allocation) for the\nV2_KICH_BAN_TEST.md rewrite verification.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: Trích golden numbers từ engine (KV1 + KV2)

**Files:**
- Modify (tạm): `spec/tmp_golden_numbers_spec.rb` — thêm in số
- Read: KV1 golden numbers từ engine spec hiện có (Task 1 Step 2)

- [ ] **Step 1: Mở rộng spec tạm để in toàn bộ calculations**

Thay nội dung `it` bằng đoạn in golden numbers (chính xác + làm tròn) cho cả 2 zone:

```ruby
  it "in golden numbers KV1 + KV2" do
    s1 = setup_zone_one_full_sample
    s2 = setup_zone_two_full_sample(period: s1.period)

    [s1.zone, s2.zone].each do |zone|
      CalculationOrchestrator.new(zone: zone, period: s1.period).call
      puts "===== #{zone.name} ====="
      Calculation.where(period: s1.period)
                 .joins(:contact_point)
                 .merge(ContactPoint.where(id: ContactPoint.in_zone(zone)))
                 .order(:contact_point_id).each do |c|
        puts "#{c.contact_point.name}: std=#{c.total_standard.to_s('F')} " \
             "loss=#{c.loss_deduction.to_s('F')} pump_use=#{c.water_pump_usage.to_s('F')} " \
             "deficit=#{c.deficit.to_s('F')} surplus=#{c.surplus.to_s('F')} " \
             "deficit_amt=#{c.deficit_amount.to_s('F')}"
      end
    end
    expect(true).to be(true)
  end
```

(Điều chỉnh `ContactPoint.in_zone` theo tên scope thật tìm ở Task 1; nếu không có, lọc thủ công theo zone qua unit_id/zone_id. In thêm field nào cần cho doc: residential_standard, water_pump_standard, savings/division/unit_public/other deduction, remaining_standard, residential_usage, total_usage.)

- [ ] **Step 2: Chạy và bắt output**

Run: `bin/docker rspec spec/tmp_golden_numbers_spec.rb`
Expected: PASS + in ra số chính xác per đầu mối cho KV1 và KV2. Lưu output vào scratchpad.

- [ ] **Step 3: Đối chiếu KV1 với engine spec hiện có + T01–T04 file cũ**

So output KV1 với assertion trong engine spec (Task 1 Step 2) và golden numbers T01–T04 file cũ. Phải khớp. Nếu lệch → dừng, điều tra (có thể engine đã đổi; báo người dùng trước khi tiếp).

- [ ] **Step 4: Kiểm tra KV2 không rơi vào edge ngoài ý muốn**

Xác nhận KV2: C (tổn hao) > 0, B > 0, không cảnh báo bất thường. Nếu C < 0 (main usage 3000 quá thấp/cao) → chỉnh `usage` hoặc meter readings trong helper (Task 2 Step 3), chạy lại. Ghi lại số input cuối cùng đã dùng.

- [ ] **Step 5: Xóa spec tạm**

```bash
git rm -f --ignore-unmatch spec/tmp_golden_numbers_spec.rb 2>/dev/null; rm -f spec/tmp_golden_numbers_spec.rb
```

(Spec tạm không commit — chỉ để trích số, đúng ranh giới "không viết RSpec mới làm deliverable".)

---

## Task 4: Viết Phần 0 + Phần 1 (Mở đầu + Dữ liệu mẫu)

**Files:**
- Overwrite: `docs/V2_KICH_BAN_TEST.md` (bắt đầu file mới)

- [ ] **Step 1: Viết header + Phần 0 (Mở đầu)**

Header version mới (bump 2.0.0, ngày 31/05/2026), nguồn NGHIEP_VU v2.13.0 / THIET_KE v2.13.0 / HANH_VI v1.2.0 / CHIEU_TEST v1.2.0. Phần 0 gồm: mục đích (hybrid), bảng quan hệ 4 tài liệu (từ spec mục 1), quy ước (ID nhóm, tag, làm tròn, cross-ref — từ spec mục 3), mục lục 6 phần.

- [ ] **Step 2: Viết Phần 1 (Dữ liệu mẫu 2 khu vực)**

1A Khu vực 1 (khớp `sample_data.rb`): cấu hình chung, 7 rank, cấu trúc cây, bảng quân số, bảng chỉ số công tơ, cột Khác, phân bổ bơm nước. 1B Khu vực 2: bảng entity (từ spec Phần 1B) + số liệu input **đã dùng thật** trong helper (Task 3 Step 4). 1C: bảng 6 tài khoản × 2 khu vực (10 tài khoản, từ spec Phần 1C). Ghi rõ KV1 cover gì, KV2 bù gì.

- [ ] **Step 3: Commit Phần 0+1**

```bash
git add docs/V2_KICH_BAN_TEST.md
git commit -m "$(printf 'Rewrite V2_KICH_BAN_TEST.md: intro + sample data (2 zones)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 5: Viết Phần 2 (Golden numbers từ engine)

**Files:**
- Modify: `docs/V2_KICH_BAN_TEST.md`

- [ ] **Step 1: Viết golden numbers KV1**

ID `EN-KV1-*`. Bảng tổn hao (A/B/C + per công tơ + per đầu mối), bơm nước (D + per đối tượng + xuống đầu mối), summary per đầu mối sinh hoạt (đầy đủ cột), hàng tổng. Mỗi số: chính xác (công thức) + hiển thị. Lấy từ output Task 3.

- [ ] **Step 2: Viết golden numbers KV2**

ID `EN-KV2-*`. Tương tự KV1 cho 3 đầu mối sinh hoạt KV2 (Quân y, Trinh sát, Chỉ huy khu vực 2). Nhấn: phân bổ bơm nước thuần hệ số (không % cố định).

- [ ] **Step 3: Commit Phần 2**

```bash
git add docs/V2_KICH_BAN_TEST.md
git commit -m "$(printf 'Rewrite V2_KICH_BAN_TEST.md: engine-verified golden numbers\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 6: Viết Phần 3 (6 nhóm giao điểm nguy hiểm)

**Files:**
- Modify: `docs/V2_KICH_BAN_TEST.md`

- [ ] **Step 1: Viết GD1–GD3**

GD1 (Kỳ × Vai trò × Entity state): tạo CP kỳ N-1 → xóa kỳ N → mở lại N-1 → 6 vai trò thấy gì + SA dropdown with_discarded. GD2 (Kỳ × Loại đầu mối × Cleanup): xóa từng loại trong KV1, data nào xóa/giữ, ảnh hưởng engine khi tính lại. GD3 (Vai trò × Thuộc về × Trang): dùng KV1 (CP đơn vị) + KV2 (CP khu vực trực tiếp), ai thấy gì. Mỗi kịch bản: tiên quyết → bước → expected (số từ Phần 2) + cross-ref chiều CHIEU_TEST.

- [ ] **Step 2: Viết GD4–GD6**

GD4 (Kỳ đang xem × Tính toán × Vai trò): chưa tính/stale/Excel/SA mở kỳ cũ xem kỳ khác. GD5 (Vị trí phân cấp × Output): 5 vị trí (KV1 có 4, KV2 thêm vị trí 3 "Quân y") → merge HTML + Excel + số cột theo role. GD6 (Cách nhận data × Kỳ × Loại): tạo giữa kỳ, thêm rank, mở kỳ mới kế thừa, main_meter không kế thừa.

- [ ] **Step 3: Commit Phần 3**

```bash
git add docs/V2_KICH_BAN_TEST.md
git commit -m "$(printf 'Rewrite V2_KICH_BAN_TEST.md: 6 dangerous-intersection scenario suites\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 7: Viết Phần 4 (Walkthrough 18 trang × 6 vai trò)

**Files:**
- Modify: `docs/V2_KICH_BAN_TEST.md`

- [ ] **Step 1: Viết nhóm XEM KẾT QUẢ + NHẬP LIỆU (6 trang)**

dashboard, billing, history, electricity_supply, meter_entries, pump_entries. Mỗi trang × 6 vai trò: số cột, data rows (số từ Phần 2), input state (CMD/kỳ cũ disabled), nút (can?), cảnh báo, sidebar, trạng thái rỗng. ID `TR-<trang>-<vaitro>`. Cross-ref CHIEU_TEST chiều 3. Không chép ma trận — instance hóa cụ thể.

- [ ] **Step 2: Viết nhóm KHAI BÁO + THIẾT LẬP + HỆ THỐNG (12 trang)**

contact_points, blocks, groups, unit_config, zones, units, pump_allocations, pricing, ranks, users, audit_logs, backups. Cùng pattern Step 1.

- [ ] **Step 3: Commit Phần 4**

```bash
git add docs/V2_KICH_BAN_TEST.md
git commit -m "$(printf 'Rewrite V2_KICH_BAN_TEST.md: per-page x 6-role walkthroughs\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 8: Viết Phần 5 (Vận hành) + Phần 6 (Truy vết)

**Files:**
- Modify: `docs/V2_KICH_BAN_TEST.md`
- Read: `spec/` (grep cho traceability)

- [ ] **Step 1: Viết Phần 5 (Vận hành)**

Vòng đời kỳ (mở đầu/mở mới + kế thừa với số KV1→kỳ kế tiếp/đóng/mở lại + StructureChangeGuard + cảnh báo mismatch/tháng 12→1). CRUD/validation cụ thể (ràng buộc mục 24 nghiệp vụ). Auth/session/backup/nhật ký. ID `VH-*`.

- [ ] **Step 2: Lập bản đồ truy vết Phần 6**

Run: `grep -rln "describe\|RSpec.describe" spec/models spec/services spec/requests spec/system`
Dùng để map kịch bản → file RSpec. Bảng: ID kịch bản → chiều CHIEU_TEST → nhóm giao điểm → file RSpec (nếu có). Ghi chú automation (ưu tiên, test chỉ thủ công).

- [ ] **Step 3: Viết mục Lịch sử thay đổi (changelog)**

Thêm mục cuối: v2.0.0 (31/05/2026) — viết lại toàn bộ theo cấu trúc 6 phần, 6 vai trò, 2 khu vực, golden numbers verify bằng engine, truy vết RSpec. (Theo feedback: update doc phải bump version + changelog.)

- [ ] **Step 4: Commit Phần 5+6**

```bash
git add docs/V2_KICH_BAN_TEST.md
git commit -m "$(printf 'Rewrite V2_KICH_BAN_TEST.md: operations + traceability + changelog\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 9: Rà soát toàn file + đối chiếu spec

**Files:**
- Read: `docs/V2_KICH_BAN_TEST.md` (toàn bộ)

- [ ] **Step 1: Đối chiếu coverage với spec + CHIEU_TEST**

Checklist: đủ 6 phần? đủ 6 vai trò mọi nơi? đủ 6 nhóm giao điểm? đủ 18 trang? mọi golden number trỏ về Phần 2 (không có số tính tay rời rạc)? KV1 khớp sample_data.rb? KV2 input khớp helper đã commit?

- [ ] **Step 2: Quét placeholder + nhất quán**

Run: `grep -n "TBD\|TODO\|XXX\|FIXME\|\.\.\." docs/V2_KICH_BAN_TEST.md`
Expected: không còn placeholder. Kiểm tra ID nhất quán (tiền tố đúng nhóm), không viết tắt (CLAUDE.md), số phân cách tiếng Việt.

- [ ] **Step 3: Kiểm tra link + mục lục**

Mục lục khớp tiêu đề; cross-ref tới CHIEU_TEST/HANH_VI đúng mục.

- [ ] **Step 4: Chạy suite để chắc helper KV2 không phá test hiện có**

Run: `bin/docker rspec spec/support` (hoặc spec dùng sample_data) — xác nhận helper additive không làm hỏng gì. Nếu suite lớn (>2 phút) → hỏi trước hoặc chạy tập con liên quan.
Expected: 0 failures.

- [ ] **Step 5: Commit sửa rà soát (nếu có)**

```bash
git add -A
git commit -m "$(printf 'Polish V2_KICH_BAN_TEST.md: review fixes, consistency\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

- [ ] **Step 6: Cập nhật memory**

Cập nhật `project_kich_ban_test_rewrite.md`: trạng thái "Đã làm" + trỏ tới spec/plan. (Hoặc xóa nếu không còn pending.)

---

## Self-Review (đã chạy khi viết plan)

**1. Spec coverage:** Mỗi phần spec (Phần 0–6, dữ liệu 2 zone, golden numbers engine, ID nhóm, truy vết RSpec, helper additive) đều có task tương ứng (Task 4–8 = Phần 0–6; Task 2 = helper; Task 3 = golden numbers; Task 8 Step 2 = truy vết). ✓

**2. Placeholder scan:** Golden numbers "lấy từ Task 3" là chỉ dẫn chạy lệnh cụ thể, không phải hand-wave. Section content checklist trỏ về spec đã liệt kê chi tiết. Helper code đầy đủ. ✓

**3. Type consistency:** `setup_zone_two_full_sample(period:)` dùng nhất quán Task 2/3/9; private builder `_kv2` + tái dùng `build_sample_ranks_lookup`/`apply_other_deduction`; trait factory xác nhận ở Task 1 trước khi dùng Task 2. `spec/tmp_golden_numbers_spec.rb` tạo Task 2, xóa Task 3. ✓
