# Vai trò Chỉ huy Sư đoàn (division_commander) — retrospective spec

> **Phiên bản:** 0.1.0
> **Ngày:** 25/06/2026
> **Tính chất:** ADR retrospective — ghi quyết định đã triển khai; không phải spec trước khi build.

**Nguồn nghiệp vụ:** `V2_XAC_NHAN_NGHIEP_VU.md` mục 11.5 (v2.18.0, fold từ đợt 2 xác nhận nghiệp vụ — Issue #418, #419).

**Plan triển khai:** `docs/superpowers/plans/2026-06-21-division-commander-role.md`.

**Phạm vi:** Quyết định kiến trúc cho việc thêm vai trò thứ 7 vào hệ thống. Không lặp lại hành vi chi tiết per trang (xem `V2_HANH_VI_HE_THONG.md` mục 1 + 4, `V2_CHIEU_TEST.md` chiều 2 + 3).

---

## Quyết định (ADR)

### ADR-061: Thêm vai trò Chỉ huy Sư đoàn — enum riêng, system-wide read-only + recalculate
- **Trạng thái:** Accepted · 25/06/2026 (retrospective — feature triển khai 22/06/2026 qua PR #429)
- **Bối cảnh:** Khách yêu cầu (đợt 2 nghiệm thu Acceptance, Issue #418/#419): Chỉ huy Sư đoàn cần xem toàn hệ thống (mọi khu vực, mọi đơn vị) nhưng không sửa gì — giống chỉ huy đơn vị nhưng phạm vi toàn hệ thống thay vì 1 đơn vị. Không thuộc đơn vị nào. Hệ thống trước đó có 5 enum values (4 nghiệp vụ + 1 kỹ thuật), 6 vai trò thực tế (UA/CMD mỗi cái chia 2 variant zone-manager).
- **Quyết định:** Thêm `division_commander` làm giá trị enum thứ 6 trong `user_role` (PostgreSQL `ALTER TYPE`), tạo vai trò thực tế thứ 7. DC nhận `can :read` trên mọi model (system-wide scope, không có `:manage`/`:create`/`:update`/`:destroy`). Có `:recalculate, Calculation` (giống SA và UA — quyền tính toán lại không phải quyền sửa dữ liệu). Không thuộc đơn vị (`unit_id = nil`). Helper `User#system_wide_scope?` trả `true` cho cả SA và DC, dùng xuyên suốt ~20 điểm kiểm tra display/filter. Sidebar 16 mục (tất cả trừ Tài khoản và Sao lưu dữ liệu). Guardrail matrices mở rộng 6→7 vai trò.
- **Lý do:** (1) Enum riêng thay vì flag trên role hiện có — DC có phạm vi khác biệt căn bản (toàn hệ thống, không thuộc đơn vị) so với mọi vai trò khác; flag sẽ tạo tổ hợp phức tạp. (2) Read-only + recalculate — khách muốn xem + kiểm tra số liệu (bấm tính lại) nhưng không can thiệp dữ liệu; recalculate không thay đổi input, chỉ cập nhật output từ input hiện có. (3) `system_wide_scope?` — gom logic "SA hoặc DC" vào 1 method tránh rải `system_admin? || division_commander?` khắp codebase.
- **Tradeoff:** (+) Sạch, rõ ràng, không ảnh hưởng role hiện có, guardrails tự mở rộng. (−) ~40 file thay đổi cho 1 vai trò read-only; mỗi trang view cần check `can?(:update, ...)` cho DC disabled (đã có sẵn cho CMD — cùng pattern).
- **Phương án đã loại:** (a) Tái dùng `commander` + flag `system_wide` — phạm vi DC (toàn hệ thống, không đơn vị) khác căn bản CMD (1 đơn vị); flag tạo tổ hợp SA×system_wide + CMD×system_wide mà chỉ cần 1. (b) Tạo tài khoản SA thứ hai với quyền bị cắt — CanCan không hỗ trợ "SA nhưng chỉ read" gọn; phải override nhiều chỗ, dễ rò quyền.
- **Điều kiện xem lại:** Khi thêm vai trò tương tự (ví dụ: Chỉ huy Lữ đoàn) — cân nhắc liệu pattern enum + `system_wide_scope?` có scale hay cần hệ thống role phân cấp.

---

## Ảnh hưởng tới các spec trước

7 spec viết trước khi thêm DC ghi "6 vai trò" — đúng tại thời điểm viết. Nay hệ thống có 7 vai trò. Per ADR-002 (không viết lại tài liệu lịch sử), các spec đó giữ nguyên nội dung + thêm ghi chú ở đầu file trỏ về ADR-061.

Danh sách spec cần ghi chú:

1. `2026-05-31-v2-kich-ban-test-rewrite-design.md`
2. `2026-06-07-app-version-reporting-design.md`
3. `2026-06-13-dimension-review-tuan-agents-design.md`
4. `2026-06-13-truy-vet-chieu-test-design.md`
5. `2026-06-14-mutation-testing-loi-tinh-toan-design.md`
6. `2026-06-14-role-behavior-coverage-design.md`
7. `2026-06-14-role-coverage-guardrail-design.md`

---

## Truy vết

- Nghiệp vụ: `V2_XAC_NHAN_NGHIEP_VU.md` mục 11.5 (anchor implicit)
- Issue: #418 (tên hệ thống + DC), #419 (DC role), #462 (retrospective ADR)
- PR triển khai: #429
- Plan: `docs/superpowers/plans/2026-06-21-division-commander-role.md`
- Canonical docs đã cập nhật: `V2_HANH_VI_HE_THONG.md` v1.5.0, `V2_CHIEU_TEST.md` v1.5.0, `V2_THIET_KE_HE_THONG.md` v2.17.0, `V2_KICH_BAN_TEST.md` v2.0.3, hướng dẫn sử dụng v1.8.0

---

## Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| 0.1.0 | 25/06/2026 | Tạo retrospective spec: ADR-061 ghi quyết định thêm DC đã triển khai. Issue #462. |
