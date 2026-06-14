---
title: Sàn coverage chống-tụt (ratchet) + vá branch gap có mục tiêu
version: 0.1.0
date: 2026-06-14
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Sàn coverage chống-tụt (ratchet) + vá branch gap có mục tiêu

Issue [#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360) đã ship SimpleCov (line + branch) ở chế độ **observe-first**: job `tests` trong CI chạy với `COVERAGE=1` nhưng **chưa có ngưỡng cứng** — comment trong `spec/spec_helper.rb` và `.github/workflows/ci.yml` ghi rõ "no hard minimum yet". Hệ quả: một PR có thể làm **tụt** coverage mà CI vẫn xanh, không ai thấy. Đây là follow-up [#381](https://github.com/manhcuongdtbk/electric-water-management/issues/381) để khép lỗ đó.

Số liệu CI mới nhất (đo với `COVERAGE=1`, full suite): **line 97,09%** (2572/2649), **branch 81,15%** (762/939 — **177 nhánh chưa phủ**). Line rất cao; branch là chỗ yếu, chưa khoanh được nhánh nào là *đường nghiệp vụ thật chưa test* vs *guard phòng thủ tầm thường*.

**Ràng buộc cốt lõi định hình thiết kế:** gate `%` **không phải** thước đo chất lượng test. Một ngưỡng đặt cao/aspirational sẽ **khuyến khích viết test rỗng để qua %** — đúng cái mà [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373) (behavior coverage, precondition chống-vacuous) và [#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358) (mutation testing) đang chống. Vì vậy vai trò của `minimum_coverage` ở đây **chỉ là sàn chống hồi quy** (ratchet đặt sát dưới hiện tại); chất lượng test do **guardrail cấu trúc** lo (access [#359](https://github.com/manhcuongdtbk/electric-water-management/issues/359), behavior [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373), 12 chiều test [ADR-030](2026-06-13-truy-vet-chieu-test-design.md), mutation [#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358)).

## Goals

- **Chặn hồi quy âm thầm:** một PR làm tụt coverage xuống dưới sàn → **CI đỏ ngay**.
- **Sàn = ratchet, không aspirational:** đặt sát dưới hiện tại (line 96%, branch 80%), siết dần khi coverage tăng có chủ đích — KHÔNG đặt cao để ép viết thêm test.
- **Vá branch gap có mục tiêu:** phân loại 177 nhánh hở; nhánh là đường nghiệp vụ thật → viết test assert hành vi; nhánh guard phòng thủ tầm thường → `# :nocov:` kèm lý do hoặc chấp nhận. KHÔNG đuổi số tròn.
- **Chỉ gate trên CI:** sàn chỉ áp với full suite dưới `COVERAGE=1` (AGENTS: không chạy coverage cục bộ — CI cover).

## Non-Goals (cố ý KHÔNG làm)

- **Tự động ratchet (auto-bump sàn mỗi PR).** SimpleCov không lưu được giá trị lần trước giữa các lần chạy CI nếu không commit một file state — quá nhiều moving-part cho ích lợi nhỏ. Sàn để **tĩnh**, bump tay khi coverage tăng có chủ đích (xem ADR-060). YAGNI.
- **Nâng sàn thành bia chất lượng.** Không lấy `%` làm KPI; không ép một con số tròn. Chất lượng do guardrail cấu trúc lo.
- **Job CI mới / cổng coverage riêng.** `COVERAGE=1` đã có trong job `tests`; `minimum_coverage` chạy sẵn ở `at_exit` của SimpleCov, fail process → fail job. Không thêm moving-part.
- **Gate coverage cục bộ.** `minimum_coverage` chỉ đúng khi full suite chạy; chạy subset cục bộ với `COVERAGE=1` sẽ under-report và đỏ giả → không khuyến khích, không hook cục bộ.

## Glossary (khoá nghĩa — không viết tắt)

| Thuật ngữ | Nghĩa |
|---|---|
| **ratchet (sàn chống-tụt)** | Ngưỡng tối thiểu đặt **sát dưới** mức hiện tại, chỉ siết lên (không nới xuống), nhằm chặn tụt mà vẫn chừa headroom cho dao động nhỏ giữa các PR. Vai trò: chống hồi quy, không phải mục tiêu. |
| **line coverage** | Tỉ lệ dòng thực thi được ít nhất một test chạy qua. |
| **branch coverage** | Tỉ lệ nhánh điều kiện (mỗi `if/else`, `&&`, `||`, `?:`, `rescue`) được test đi qua **cả hai phía**. Khắt khe hơn line. |
| **branch gap** | Một nhánh điều kiện chưa được test đi qua (một phía hoặc cả hai). |
| **`# :nocov:`** | Marker SimpleCov loại một đoạn khỏi phép đo coverage. Chỉ dùng cho **guard phòng thủ tầm thường** (đường gần như không xảy ra trong vận hành), kèm **lý do một dòng tiếng Anh**. |
| **vacuous test** | Test chạy qua code nhưng không assert hành vi thật (chỉ để nâng %). Cấm — nghịch [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373)/[#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358). |

## Thiết kế

Tách **hai phần** (có thể hai PR) vì rủi ro và bản chất khác nhau:

### Phần A — Sàn ratchet (nhỏ, mechanical)

Thêm vào block `SimpleCov.start` trong `spec/spec_helper.rb`:

```ruby
minimum_coverage line: 96, branch: 80
```

SimpleCov so phần trăm tổng ở `at_exit`; dưới sàn → exit non-zero → fail job `tests`. Đồng thời:

- Thay comment "no hard minimum yet — observe first" trong `spec/spec_helper.rb` bằng ghi chú giải nghĩa **ratchet** + cảnh báo chỉ áp full suite.
- Sửa comment `no hard minimum yet` trong `.github/workflows/ci.yml` (dòng `COVERAGE: "1"`) cho khớp.

**Chọn ngưỡng:** line 96 (headroom ~1,1pt dưới 97,09%), branch 80 (headroom ~1,15pt dưới 81,15%). Đủ rộng để một PR refactor lành tính không đỏ giả, đủ hẹp để bắt một test bị xóa/skip thật. Verify gate cắn: tạm nâng sàn trên mức hiện tại → CI phải đỏ; khôi phục.

### Phần B — Vá branch gap có mục tiêu (cần đọc report)

1. Sinh report: `COVERAGE=1 bin/docker rspec` (full suite ~10 phút — chạy nền/chia nhỏ). Đọc `coverage/index.html`.
2. Phân loại 177 nhánh hở thành hai nhóm:
   - **Đường nghiệp vụ thật chưa test** → viết test **assert hành vi thật** (không vacuous). Ưu tiên `app/services` (lõi tính tiền) rồi `app/models`.
   - **Guard phòng thủ tầm thường** (rescue gần như không xảy ra, fallback `&.`/`||` cho trạng thái không đạt được trong vận hành) → `# :nocov:` kèm lý do một dòng tiếng Anh, hoặc chấp nhận để nguyên.
3. Sau khi branch coverage tăng, **bump sàn branch** trong cùng PR để giữ ~1pt dưới mức mới (ratchet siết lên). KHÔNG đuổi số tròn — bump bám theo mức thực đo được.

## Quyết định (ADR)

### ADR-060: Sàn coverage là ratchet chống-tụt, không phải bia aspirational; bump tay
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** SimpleCov ([#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360)) đang observe-first, không có ngưỡng cứng → PR có thể tụt coverage mà CI xanh. Coverage hiện cao (line 97,09%, branch 81,15%). Có hai cám dỗ trái ngược: (a) không gate gì → hồi quy âm thầm; (b) gate cao/aspirational → khuyến khích test rỗng để qua %, nghịch triết lý chống-vacuous của [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373)/[#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358).
- **Quyết định:** Đặt `minimum_coverage line: 96, branch: 80` trong `spec/spec_helper.rb` (chỉ áp khi `COVERAGE=1`, full suite trên CI). Ngưỡng đặt **sát dưới** mức hiện tại làm **sàn chống hồi quy**, KHÔNG phải mục tiêu chất lượng. Sàn **tĩnh, bump tay** khi coverage tăng có chủ đích (vd sau khi vá branch gap), giữ ~1pt headroom dưới mức mới — không tự động hoá. Chất lượng test do guardrail cấu trúc lo (access [#359](https://github.com/manhcuongdtbk/electric-water-management/issues/359), behavior [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373), 12 chiều test [ADR-030](2026-06-13-truy-vet-chieu-test-design.md), mutation [#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358)); gate `%` chỉ giữ vai trò sàn-hồi-quy hẹp.
- **Lý do:** Sàn sát-dưới chặn được tụt thật mà vẫn chừa headroom cho dao động lành tính giữa PR, không tạo áp lực viết test rỗng. Bump tay đủ dùng (coverage tăng là sự kiện hiếm, có chủ đích) và tránh moving-part của state-file tự ratchet.
- **Tradeoff:** (+) Chặn hồi quy âm thầm với gần như zero machinery; không khuyến khích vacuous test. (−) Sàn không tự siết — phải nhớ bump tay khi coverage tăng đáng kể (nếu quên thì chỉ mất độ chặt, không sai).
- **Phương án đã loại:**
  - *Gate aspirational (vd line 99 / branch 90):* loại — ép viết test để qua %, đẻ vacuous test, nghịch [#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373)/[#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358).
  - *Tự động ratchet (commit file state, auto-bump mỗi PR):* loại — SimpleCov không có cơ chế persist sẵn; tự xây tốn moving-part, ích lợi nhỏ (YAGNI).
  - *Không gate, chỉ observe mãi:* loại — chính là hiện trạng [#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360) để lại, không chặn được hồi quy.
  - *Sàn sát-sạt (line 97 / branch 81):* loại — headroom ~0,1pt quá hẹp, một test skip/xóa lành tính cũng đỏ giả, nhiều ma sát.
- **Điều kiện xem lại:** Nếu dao động coverage giữa PR thường xuyên chạm sàn (đỏ giả) → nới headroom hoặc rà nguồn dao động. Nếu việc bump tay liên tục bị quên khiến sàn tụt hậu xa so với thực tế → cân nhắc lại auto-ratchet.

## Truy vết

- Yêu cầu: [#381](https://github.com/manhcuongdtbk/electric-water-management/issues/381) (follow-up [#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360)).
- Cùng họ "đo chất lượng test": [#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358) (mutation), [#359](https://github.com/manhcuongdtbk/electric-water-management/issues/359)/[#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373) (role/behavior coverage).
- Triển khai: PR Phần A (sàn ratchet) base `develop`; PR Phần B (vá branch gap + bump sàn branch) base `develop`, `Closes #381`.

## Lịch sử thay đổi

| Phiên bản | Ngày | Thay đổi |
|---|---|---|
| 0.1.0 | 2026-06-14 | Tạo spec: sàn coverage ratchet (line 96 / branch 80) + vá branch gap có mục tiêu; ADR-060. |
