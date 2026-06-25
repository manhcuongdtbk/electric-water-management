---
title: CI guardrail NV-... requirement-to-test traceability
version: 0.2.0
date: 2026-06-25
governed_by: 2026-06-08-truy-vet-quan-ly-thay-doi-design.md
---

# CI guardrail NV traceability

> **Ghi chú:** Spec này hiện thực hoá đường nâng cấp của ADR-014 (deferred CI enforcement requirement→test) — điều kiện xem lại đã đạt: 5 anchor `NV-...` trong canonical, pattern `CHIEU-...` (ADR-030) đã chứng minh hiệu quả.

## Bối cảnh

Dự án truy vết yêu cầu nghiệp vụ → thiết kế → test → release qua anchor `NV-...` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` (ADR-013..015). Hiện có 5 anchor:

| Anchor | Mô tả |
|---|---|
| `NV-cot-khac-he-so-don-vi` | Cột "Khác" dạng hệ số đơn vị |
| `NV-hien-thi-chi-tiet-ton-hao` | Hiển thị chi tiết tổn hao |
| `NV-phan-bo-bom-theo-tram` | Phân bổ bơm nước theo trạm |
| `NV-nhat-ky-he-thong` | Nhật ký hệ thống |
| `NV-sao-luu-phuc-hoi` | Sao lưu và phục hồi |

Demo specs tham chiếu NV qua metadata `demo_nv`. Design specs tham chiếu NV trong `## Truy vết`. Nhưng **regular specs không tham chiếu NV** — CI không có gì để đối chiếu "yêu cầu NV-xxx có test cover không?"

Pattern `CHIEU-...` (ADR-030) đã chứng minh cách nhúng anchor vào `it` descriptions + CI cross-check:
- Spec khai `CHIEU-slug` trong bảng `## Truy vết chiều test`
- Test nhúng `it "CHIEU-slug: mô tả"`
- CI script `check-test-dimensions.sh` đối chiếu 4 luật (required có test, DEFERRED có #issue, orphan, unique)

---

## Quyết định (ADR)

### ADR-065: CI guardrail NV-... requirement-to-test traceability
- **Trạng thái:** Accepted · 25/06/2026
- **Bối cảnh:** ADR-014 hoãn CI ép truy vết yêu cầu→test vì chưa đủ anchor NV. Nay có 5 anchor + pattern CHIEU đã chứng minh. Regular specs không tham chiếu NV → CI không bắt được yêu cầu thiếu test.
- **Quyết định:** Thêm script `check-nv-traceability.sh` vào job `doc-governance` (cùng pattern fail-loud ADR-024). Cơ chế song song CHIEU:

  **Khai báo (nguồn sự thật):** `<a id="NV-xxx">` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` — đã tồn tại, không cần thêm bảng.

  **Test tags:** nhúng `NV-xxx` vào mô tả `it` của test (ít nhất 1 test per anchor):
  ```ruby
  it "NV-cot-khac-he-so-don-vi: calculates unit_coefficient correctly" do
    # ...
  end
  ```
  Một test có thể mang nhiều NV tag. Một NV anchor có thể có nhiều test.

  **DEFERRED:** file `.github/nv-test-deferred.txt` liệt kê anchor hoãn kèm gate issue:
  ```
  NV-nhat-ky-he-thong #441
  ```

  **4 luật CI:**

  | Luật | Đỏ khi |
  |---|---|
  | R1 — Required có test | Anchor NV trong canonical không DEFERRED mà không có `it "NV-xxx` nào trong `spec/` |
  | R2 — DEFERRED có gate | Dòng DEFERRED trong `.github/nv-test-deferred.txt` thiếu `#<số>` |
  | R3 — Orphan | Tag `NV-xxx` trong test `it` không khớp anchor nào trong canonical (typo/anchor đã xóa) |
  | R4 — Orphan deferred | Dòng DEFERRED tham chiếu NV-xxx không tồn tại trong canonical |

  **Scope grep:** `spec/**/*.rb` (gồm cả `spec/demo/`). Demo specs dùng `demo_nv` metadata — script cũng grep `NV-xxx` trong `demo_nv: %w[NV-xxx]` để đếm coverage (không chỉ `it` descriptions).

- **Lý do:** Tái dùng pattern đã chứng minh (CHIEU). Chi phí CI thêm <5 giây (grep). Dev chỉ thêm `NV-xxx:` vào `it` description — chi phí gần 0. File deferred đơn giản, grepable, audit-friendly.
- **Tradeoff:** (+) Máy ép, bắt yêu cầu thiếu test ngay tại PR. Deferred cho phép hoãn có gate. (−) Dev phải nhớ thêm NV tag khi viết test cho yêu cầu mới. PR template đã nhắc (mục traceability). Chỉ bắt NV anchor đã khai — yêu cầu chưa gắn anchor thì vô hình (việc khai anchor vẫn prose/kỷ luật).
- **Phương án đã loại:** (a) Tham chiếu qua design spec `## Truy vết` (chain canonical→spec→test) — phức tạp hơn, phải parse nhiều file, khó grep. (b) Metadata block riêng trong spec file (tương tự `demo_nv`) — tạo convention mới khi CHIEU đã chứng minh nhúng vào `it` đủ tốt. (c) Không làm gì — anchor NV tồn tại nhưng CI không ép → drift âm thầm.
- **Điều kiện xem lại:** Khi số anchor NV tăng đáng kể (>20) hoặc khi pattern "nhúng vào `it`" gây nhiễu test output — cân nhắc chuyển sang metadata approach.

---

## Truy vết

- Issue: #441
- Tiền đề: ADR-014 (deferred condition met), ADR-030 (CHIEU precedent)
- Canonical doc: `docs/V2_XAC_NHAN_NGHIEP_VU.md` (anchors `NV-...`)
- CI job: `doc-governance` trong `.github/workflows/ci.yml`

---

## Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| 0.2.0 | 25/06/2026 | ADR-065 implemented: script `check-nv-traceability.sh` wired into job `doc-governance`. 6 NV anchors covered (2 via test `it` tags, 4 via `demo_nv`). Added anchor `NV-vai-tro-chi-huy-su-doan` to canonical (was orphan). Issue #441. |
| 0.1.0 | 25/06/2026 | Tạo spec: ADR-065 (CI guardrail NV traceability — 4 luật, song song CHIEU). Issue #441. |
