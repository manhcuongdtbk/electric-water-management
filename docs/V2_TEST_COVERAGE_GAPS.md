# Kết quả rà soát test coverage theo 12 chiều kiểm thử

> **Ngày rà soát:** 23/05/2026
> **Cơ sở:** docs/V2_CHIEU_TEST.md v1.0.0, 1129 test cases hiện có
> **Trạng thái:** Đang xử lý

---

## Tổng quan

| Chiều | Trạng thái | Gap chính |
|---|---|---|
| 1 - Trạng thái kỳ | ⚠️ Thiếu | State A chưa test trên 9+ trang |
| 2 - Vai trò | ⚠️ Thiếu nhiều | 6+ trang chỉ test SA (1/6 role) |
| 3 - Trang/thao tác | — | Đánh giá qua chiều 1 + 2 |
| 4 - Entity state | ✅ Tốt | Gap nhỏ: MainMeter discard visibility |
| 5 - Loại đầu mối | ⚠️ Thiếu | Public, water_pump discard cleanup chưa test riêng |
| 6 - Thuộc về | ✅ Tốt | Cover qua billing, contact_points, engine specs |
| 7 - Kỳ xem ≠ kỳ mở | ⚠️ Thiếu | Kịch bản nguy hiểm chưa test. Non-SA xem kỳ cũ chưa test |
| 8 - Trạng thái tính toán | ❌ Chưa cover | Billing/dashboard khi chưa tính, stale chưa test |
| 9 - Đầy đủ dữ liệu | ✅ Tốt | Cover qua engine specs (edge cases B=0, C<0) + warning specs |
| 10 - Vị trí phân cấp | ⚠️ Thiếu | Vị trí 3 chưa test. NULLS LAST sort chưa test |
| 11 - Cách nhận data | ✅ Tốt | Cover qua period_service_spec + model after_create specs |
| 12 - HTML vs Excel | ❌ Chưa cover | Không verify nội dung xlsx |

---

## Chi tiết gap và trạng thái xử lý

### Chiều 1 — Trạng thái kỳ

**Đã cover:**
- State B (kỳ mới nhất mở): mọi test dùng mặc định
- State C (kỳ cũ mở lại): v230_structure_change_guard_integration_spec, old_period_contact_point_edit_spec, discarded_entity_visibility_spec
- State A: period_guard_spec (unit test), electricity_supply_spec, unit_config_spec, zones_spec

**Gap — State A chưa test trên các trang:**

| Trang | State A test | Trạng thái |
|---|---|---|
| billing | Chưa có | [ ] Cần thêm |
| dashboard | Chưa có | [ ] Cần thêm |
| meter_entries | Chưa có | [ ] Cần thêm |
| pump_entries | Chưa có | [ ] Cần thêm |
| pump_allocations | Chưa có | [ ] Cần thêm |
| history | Chưa có | [ ] Cần thêm |
| blocks | Chưa có | [ ] Cần thêm |
| groups | Chưa có | [ ] Cần thêm |
| ranks | Chưa có | [ ] Cần thêm |
| electricity_supply | Đã có | [x] |
| unit_config | Đã có | [x] |
| zones | Đã có | [x] |

---

### Chiều 2 — Vai trò

**Đã cover đủ 6 role:**
- billing_spec: SA, UA-ZM, UA, CMD-ZM, CMD, TECH
- contact_points_spec: SA, UA-ZM, UA, CMD-ZM, CMD, TECH

**Gap — đã cover bởi role_access_matrix_spec (108 tests, 18 trang × 6 role):**

| Trang | SA | UA-ZM | UA | CMD-ZM | CMD | TECH | Trạng thái |
|---|---|---|---|---|---|---|---|
| pump_allocations | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| blocks | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| groups | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| zones | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| units | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| ranks | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| history | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| dashboard | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| meter_entries | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| pump_entries | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| electricity_supply | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| unit_config | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| pricing | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| audit_logs | [x] | [x] | [x] | [x] | [x] | [x] | Done |
| backups | [x] | [x] | [x] | [x] | [x] | [x] | Done |

---

### Chiều 4 — Entity state

**Đã cover:**
- discarded_entity_visibility_spec (request + service): CP + Unit cross-period visibility
- Model specs: zone, unit, CP, meter, main_meter, block, group discard behavior
- pump_allocations_spec: unit/CP discard hides allocation

**Gap nhỏ:**

| Gap | Trạng thái |
|---|---|
| MainMeter standalone discard visibility (request level) | [ ] Nice-to-have |

---

### Chiều 5 — Loại đầu mối

**Đã cover:**
- Residential discard cleanup: contact_point_spec (meter_readings, personnel_entries, calculations, other_deductions)
- Non_establishment discard cleanup: contact_point_spec (non_establishment_snapshots)
- Pump_allocation cleanup on CP discard: contact_point_spec

**Gap:**

| Gap | Trạng thái |
|---|---|
| Public CP discard cleanup (meter_readings) | [ ] Cần thêm |
| Water_pump CP discard cleanup (meter_readings) | [ ] Cần thêm |

---

### Chiều 7 — Kỳ xem ≠ kỳ mở

**Đã cover:**
- SA xem kỳ cũ qua period_id: billing_spec
- SA export xlsx kỳ cũ: billing_spec
- Period selector auto-submit: billing system spec

**Gap:**

| Gap | Trạng thái |
|---|---|
| SA xem kỳ N-1 khi kỳ cũ N-2 đang mở (kịch bản nguy hiểm) | [ ] Cần thêm |
| Non-SA (UA-ZM, UA, CMD-ZM, CMD) xem kỳ cũ trên billing | [ ] Cần thêm |
| Recalculate disabled khi xem kỳ đóng (khác kỳ đang mở) | [ ] Cần thêm |
| History period selector cho non-SA | [ ] Cần thêm |

---

### Chiều 8 — Trạng thái tính toán

**Đã cover:**
- Recalculate action: billing_spec (SA thành công, CMD chặn, kỳ đóng chặn, UA-ZM thành công)

**Gap:**

| Gap | Trạng thái |
|---|---|
| Billing render khi calculations trống (chưa tính lần nào) | [x] billing_spec — SA + non-SA render "Chưa có dữ liệu tính toán" |
| Dashboard render khi calculations trống | [x] dashboard_spec — SA + UA-ZM render bình thường |
| Billing render khi calculations stale (data thay đổi sau tính) | [x] billing_spec — sửa reading_end, verify calculations giữ giá trị cũ |
| Excel export khi calculations trống | [x] billing_spec — xlsx trả file hợp lệ khi chưa tính |

---

### Chiều 10 — Vị trí phân cấp

**Đã cover:**
- rowspan_computer_spec: vị trí 1 (trực tiếp đơn vị), vị trí 4 (nhóm trong khối), vị trí 5 (khu vực trực tiếp)

**Gap:**

| Gap | Trạng thái |
|---|---|
| Vị trí 2 (trong khối, không nhóm) — rowspan test | [ ] Cần thêm |
| Vị trí 3 (trong nhóm trực tiếp, không khối) — rowspan test | [ ] Cần thêm |
| Sort order NULLS LAST cho block/group | [ ] Cần thêm |
| Excel merge cho 5 vị trí | [ ] Cần thêm (liên quan chiều 12) |

---

### Chiều 12 — HTML vs Excel

**Đã cover:**
- billing_spec: response content_type là xlsx, filename đúng
- billing_spec: export kỳ cũ trả 200

**Gap — nghiêm trọng:**

| Gap | Trạng thái |
|---|---|
| Formula correctness (SUM, tiêu chuẩn còn lại, thành tiền) | [x] billing_spec — 5 formula tests (SUM ranks, std+pump, SUM deductions, std-deduction, kw*price) |
| Column count per role (SA 30, UA-ZM 29, UA 28) | [x] billing_spec — SA header có Khu vực+Đơn vị, UA ẩn cả 2, UA-ZM có Đơn vị ẩn Khu vực |
| Cell merge correctness (khối/nhóm/đơn vị/khu vực) | [x] billing_spec — header nhóm lớn merge row 3 |
| Number format (num_fmt) | [x] billing_spec — kW=#,##0.00, tiền=#,##0, quân số=0 |
| Formula column index shift khi số cột thay đổi theo role | [x] billing_spec — UA xlsx formula vẫn reference $B$1 đúng |

---

## Thứ tự ưu tiên xử lý

| Ưu tiên | Chiều | Lý do |
|---|---|---|
| 1 | 12 (Excel) | File Excel gửi chỉ huy — sai formula/merge/cột không ai phát hiện |
| 2 | 8 (Tính toán) | Billing/dashboard crash hoặc hiểu nhầm khi chưa tính |
| 3 | 2 (Vai trò) | Lỗi phân quyền trên 6+ trang chỉ test SA |
| 4 | 7 (Kỳ xem ≠ mở) | Kịch bản nguy hiểm chưa test |
| 5 | 1 (Trạng thái kỳ) | State A trên 9 trang |
| 6 | 10 (Vị trí) | 2 vị trí chưa test rowspan |
| 7 | 5 (Loại CP) | 2 loại chưa test cleanup riêng |

---

## Lịch sử

### 23/05/2026
- Rà soát ban đầu: xác định gap cho 12 chiều.

---

## Design issues phát hiện qua audit

### Ability cấp read model thừa → vô tình mở page access

**Vấn đề:** Ability cho UA/CMD `can :read, Zone` và `can :read, Unit` để hỗ trợ data access (form dropdown, association). Nhưng vô tình cho phép truy cập /zones và /units page qua direct URL (accessible_by trả data → controller render 200).

**Thực tế:** UA-ZM/UA/CMD-ZM/CMD không bao giờ truy cập Zone/Unit qua `accessible_by`. Tất cả đều qua association (`current_user.unit.zone`) hoặc direct query (`Zone.kept.where(manager_unit_id: ...)`).

**Ảnh hưởng:** Các trang sau cho phép truy cập khi không nên:

| Trang | Role không nên access | Hiện tại | Đúng |
|---|---|---|---|
| /zones | UA, CMD (non-ZM), UA-ZM, CMD-ZM | 200 (trống hoặc read-only) | Redirect |
| /units | UA-ZM, UA, CMD-ZM, CMD | 200 (chỉ đơn vị mình) | Redirect |
| /pricing | UA-ZM, UA, CMD-ZM, CMD | 200 (read-only) | Redirect |
| /users | UA-ZM, UA, CMD-ZM, CMD | 200 (trống) | Redirect |
| /pump_allocations | UA, CMD (non-ZM) | 200 (trống) | Redirect |

**Hướng fix:** Bỏ `can :read, Zone/Unit` khỏi unit_admin/commander Ability (không ảnh hưởng nghiệp vụ vì không chỗ nào dùng accessible_by cho Zone/Unit). Hoặc thêm page-level authorize! vào controller.

**Trạng thái:** Ghi nhận, chưa fix.
