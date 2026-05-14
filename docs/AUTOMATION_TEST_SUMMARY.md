# Tổng hợp Automation Test

> Cập nhật: 2026-05-14
> Tổng specs: 1404 examples, 0 failures (`bundle exec rspec`)
> Thời gian chạy: 1 phút 41.75 giây (files took 1.25s to load)
> Số file spec: 82 (`find spec -name "*_spec.rb"`)

## 1. Spec inventory

Số examples per file đếm bằng grep (`it`/`specify`/`scenario`) — xấp xỉ; tổng
chính thức 1404 lấy từ output `rspec` (chênh do shared examples / matcher một dòng).

| Nhóm | File | Examples |
|------|------|----------|
| models | ability_spec.rb | 157 |
| models | contact_point_group_membership_spec.rb | 5 |
| models | contact_point_group_spec.rb | 13 |
| models | contact_point_other_deduction_spec.rb | 5 |
| models | contact_point_spec.rb | 22 |
| models | main_meter_reading_spec.rb | 9 |
| models | main_meter_spec.rb | 16 |
| models | meter_reading_spec.rb | 13 |
| models | meter_spec.rb | 25 |
| models | monthly_calculation_spec.rb | 10 |
| models | monthly_period_spec.rb | 20 |
| models | organization_spec.rb | 26 |
| models | personnel_spec.rb | 7 |
| models | pump_station_assignment_spec.rb | 24 |
| models | pump_station_spec.rb | 6 |
| models | rank_quota_spec.rb | 13 |
| models | unit_config_spec.rb | 8 |
| models | user_spec.rb | 30 |
| models | work_group_spec.rb | 13 |
| models | zone_spec.rb | 13 |
| requests | audit_logs_spec.rb | 5 |
| requests | backups_spec.rb | 9 |
| requests | contact_point_groups_spec.rb | 21 |
| requests | contact_points_spec.rb | 21 |
| requests | dashboard_spec.rb | 9 |
| requests | electricity_supplies_spec.rb | 20 |
| requests | f17_lockable_spec.rb | 7 |
| requests | history_spec.rb | 6 |
| requests | main_meters_spec.rb | 4 |
| requests | meter_readings_spec.rb | 29 |
| requests | meters_spec.rb | 28 |
| requests | monthly_periods_spec.rb | 11 |
| requests | monthly_summary_spec.rb | 40 |
| requests | organizations_spec.rb | 27 |
| requests | password_changes_spec.rb | 23 |
| requests | period_lock_enforcement_spec.rb | 19 |
| requests | personnel_reviews_spec.rb | 16 |
| requests | personnel_spec.rb | 15 |
| requests | pump_station_assignments_spec.rb | 26 |
| requests | pump_station_meters_spec.rb | 14 |
| requests | pump_station_readings_spec.rb | 13 |
| requests | pump_stations_spec.rb | 20 |
| requests | rack_attack_spec.rb | 3 |
| requests | rank_quotas_spec.rb | 7 |
| requests | sessions_spec.rb | 2 |
| requests | unit_configs_spec.rb | 15 |
| requests | users_spec.rb | 31 |
| requests | work_groups_spec.rb | 21 |
| requests | zones_spec.rb | 24 |
| services | backup_service_spec.rb | 14 |
| services | calculation_orchestrator_spec.rb | 38 |
| services | calculation_orchestrator_zone_loss_spec.rb | 7 |
| services | loss_calculator_spec.rb | 35 |
| services | period_inheritance_service_spec.rb | 10 |
| services | pump_allocation_calculator_spec.rb | 25 |
| services | **scenario_may2026_spec.rb** (mới) | 8 |
| services | **scenario_jun2026_spec.rb** (mới) | 8 |
| services | summary_calculator_spec.rb | 33 |
| system | authorization_cross_cutting_spec.rb | 6 |
| system | backup_spec.rb | 10 |
| system | devise_sessions_spec.rb | 10 |
| system | f01_contact_points_spec.rb | 8 |
| system | f02_meters_spec.rb | 7 |
| system | f03_personnel_spec.rb | 4 |
| system | f04_unit_configs_spec.rb | 6 |
| system | f05_electricity_supply_spec.rb | 5 |
| system | f06_meter_readings_spec.rb | 6 |
| system | f07_period_inheritance_spec.rb | 5 |
| system | f08_f11_calculation_engine_spec.rb | 12 |
| system | f12_dashboard_spec.rb | 24 |
| system | f13_history_spec.rb | 23 |
| system | f14_csv_export_spec.rb | 41 |
| system | f15_user_management_spec.rb | 10 |
| system | f17_lockable_spec.rb | 3 |
| system | f18_force_password_change_spec.rb | 7 |
| system | f18_session_timeout_spec.rb | 7 |
| system | f19_audit_log_spec.rb | 12 |
| system | f20_unit_prices_spec.rb | 7 |
| system | f21_rank_quotas_spec.rb | 8 |
| system | main_meters_spec.rb | 12 |
| system | organizations_spec.rb | 10 |
| system | pump_stations_spec.rb | 8 |
| tasks | admin_rake_spec.rb | 5 |

Tổng theo nhóm (grep): models 435 · requests 486 · services 178 · system 251 · tasks 5.

## 2. Coverage theo chức năng

| F# | Tên | Request | System | Service | Model | Status |
|----|-----|---------|--------|---------|-------|--------|
| F01 | Khai báo đầu mối | ✓ | ✓ | — | ✓ | ✅ |
| F02 | Khai báo công tơ | ✓ | ✓ | — | ✓ | ✅ |
| F03 | Khai báo quân số | ✓ | ✓ | — | ✓ | ✅ |
| F04 | Cấu hình tỷ lệ | ✓ | ✓ | — | ✓ | ✅ |
| F05 | Nhập số điện lực | ✓ | ✓ | — | ✓ | ✅ |
| F06 | Nhập chỉ số công tơ | ✓ | ✓ | — | ✓ | ✅ |
| F07 | Soát lại quân số + khóa kỳ | ✓ | ✓ | ✓ | — | ✅ |
| F08 | Tính toán tiêu chuẩn | — | ✓ | ✓ | — | ✅ |
| F09 | Tính toán sử dụng | ✓ | ✓ | ✓ | — | ✅ |
| F10 | Phân bổ bơm nước | — | — | ✓ | — | ✅ |
| F11 | Bảng tổng hợp | ✓ | ✓ | ✓ | ✓ | ✅ |
| F12 | Báo cáo tổng hợp | ✓ | ✓ | — | — | ✅ |
| F13 | Tra cứu lịch sử | ✓ | ✓ | — | — | ✅ |
| F14 | CSV export | ✓ | ✓ | — | — | ✅ |
| F15 | Quản lý tài khoản | ✓ | ✓ | — | ✓ | ✅ |
| F16 | Đăng nhập + đổi MK | ✓ | ✓ | — | — | ✅ |
| F17 | Khóa tài khoản | ✓ | ✓ | — | — | ✅ |
| F18 | Session timeout | — | ✓ | — | — | ✅ |
| F19 | Nhật ký | ✓ | ✓ | — | — | ✅ |
| F20 | Đơn giá điện | ✓ | ✓ | — | ✓ | ✅ |
| F21 | Định mức cấp bậc | ✓ | ✓ | — | ✓ | ✅ |
| — | Backup/restore | ✓ | ✓ | ✓ | — | ✅ |
| — | Period lock enforcement | ✓ | — | — | — | ✅ |

Ghi chú:
- F08–F11: engine tính toán test ở mức service (loss/pump/summary/orchestrator)
  + system `f08_f11_calculation_engine_spec.rb` + 2 scenario spec mới; F09/F11
  còn được exercise qua request `monthly_summary_spec.rb` & `dashboard_spec.rb`.
- F10 phân bổ bơm nước: chỉ test ở service layer (`pump_allocation_calculator_spec.rb`)
  — đây là engine thuần, không có UI/route riêng.
- F14 CSV: system `f14_csv_export_spec.rb` + request (`monthly_summary_spec.rb`,
  `history_spec.rb` có nhánh `.csv`).
- F16: request `sessions_spec.rb` + `password_changes_spec.rb`; system
  `devise_sessions_spec.rb` + `f18_force_password_change_spec.rb`.

## 3. Coverage theo role

Authorization test tập trung ở `spec/models/ability_spec.rb` (157 examples, CanCanCan
ability cho cả 4 role) + `spec/system/authorization_cross_cutting_spec.rb` + các
request spec kiểm tra auth per-action.

| Role | Ability spec | Request spec (auth) | System spec |
|------|-------------|---------------------|-------------|
| admin_level1 | ✓ | ✓ | ✓ |
| admin_unit | ✓ | ✓ | ✓ |
| commander | ✓ | ✓ | ✓ |
| tech | ✓ | ✓ | ✓ |

## 4. Edge cases covered

| Edge case | Trạng thái | Vị trí |
|-----------|-----------|--------|
| LossCalc — zone có nhiều MainMeter | ✓ sẵn có | `spec/services/loss_calculator_spec.rb` ("zone with multiple MainMeters") |
| SummaryCalc — other_deduction `fixed_kw` | ✓ sẵn có | `spec/services/summary_calculator_spec.rb` (context "other_deduction") |
| SummaryCalc — other_deduction `factor_per_person` | ✓ sẵn có | `spec/services/summary_calculator_spec.rb` (context "other_deduction") |
| **SummaryCalc — other_deduction ÂM (`fixed_kw` < 0)** | ✓ **mới** | `spec/services/summary_calculator_spec.rb` (context "other_deduction") |
| PumpAllocCalc — nhiều TRẠM bơm dồn về 1 CP | ✓ sẵn có | `spec/services/pump_allocation_calculator_spec.rb` ("multiple pump stations accumulate on the same CP") |
| **PumpAllocCalc — 1 trạm bơm nhiều công tơ** | ✓ **mới** | `spec/services/pump_allocation_calculator_spec.rb` ("single pump station with multiple meters") |
| Công tơ no_loss (tổn hao = 0) | ✓ sẵn có | `loss_calculator_spec.rb`, `calculation_orchestrator_spec.rb`, scenario spec mới |
| F13 — so sánh cùng kỳ 2 năm | ✓ sẵn có | `spec/system/f13_history_spec.rb` (2025 vs 2026) |
| F12 — Dashboard view quý / năm | ✓ sẵn có | `spec/requests/dashboard_spec.rb` (`view_type: "quarter"` / `"year"`) |
| CSV UTF-8 BOM | ✓ sẵn có | `spec/system/f14_csv_export_spec.rb` (`UTF8_BOM`) |
| Negative loss clamp (supply < consumption) | ✓ sẵn có | `loss_calculator_spec.rb` (warnings) |
| sum_fixed_pct > 100 → clamp variable = 0 | ✓ sẵn có | `pump_allocation_calculator_spec.rb` |
| Communal CP loại khỏi bảng thu tiền | ✓ sẵn có | `monthly_calculation_spec.rb`, scenario_may2026 spec |

## 5. Kịch bản integration (end-to-end)

Test end-to-end chạy `CalculationOrchestrator` với bộ số liệu thực tế hoàn chỉnh
(multi-zone, multi-unit, công tơ no_loss, đầu mối communal, trạm bơm fixed +
variable, ContactPointGroup, WorkGroup), assert kết quả BigDecimal với tolerance
`bd("0.01")`. Số kỳ vọng tính độc lập bằng Python BigDecimal.

- Tháng 5/2026: `spec/services/scenario_may2026_spec.rb` (8 examples)
- Tháng 6/2026: `spec/services/scenario_jun2026_spec.rb` (8 examples) — mô phỏng
  kế thừa từ T5 (đầu kỳ T6 = cuối kỳ T5), quân số thay đổi, thêm đầu mối mới,
  CPG chuyển fixed → variable.

## 6. Tối ưu đã áp dụng

- `test-prof` gem + `let_it_be` cho setup tốn kém (PR #107)
- Xóa 31 specs trùng lặp từ `calculation_orchestrator_spec` (PR #107)
- Concern `LockablePeriod` thay inline checks (PR #106)
- 2 scenario spec mới dùng `let_it_be` + `before_all` toàn bộ fixture
