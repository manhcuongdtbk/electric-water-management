---
title: Guardrail tự động cho quản trị tài liệu (link chết, bản đồ tài liệu, giữ định nghĩa thuật ngữ)
version: 0.1.1
date: 2026-06-11
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Guardrail tự động cho quản trị tài liệu

Biến bộ quản trị tài liệu ở [ADR-023](2026-06-10-quan-tri-tai-lieu-design.md) từ **prose/kỷ luật** thành **luật máy ép được**, đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép; đừng viết prose rồi mong người nhớ"). Tái dùng pattern CI bash native fail-rõ-ràng của [ADR-021](2026-06-07-ci-spec-design.md). Truy vết: GitHub Issue [`#313`](https://github.com/manhcuongdtbk/electric-water-management/issues/313).

## Bối cảnh

[ADR-023](2026-06-10-quan-tri-tai-lieu-design.md) lập `docs/THUAT_NGU.md` (từ điển canonical), `docs/BAN_DO_TAI_LIEU.md` (bản đồ tài liệu), quy tắc "sửa đừng thêm" và nguyên tắc glossary-là-lớp-đọc-hiểu — **toàn bộ ở mức prose**, không có gì ép. ADR-002 nói rõ: cái gì máy kiểm được thì để máy ép. Có **ba dạng drift kiểm được bằng máy**:

- **Link nội bộ chết** (đổi tên/xóa file làm pointer hỏng) — pattern "trỏ về thay vì chép" của ADR-023 dựa vào link còn sống.
- **Bản đồ tài liệu lệch thực tế** (file mới chưa phân loại; đường dẫn ma trong bản đồ).
- **Định nghĩa thuật ngữ bị xóa âm thầm** (một viết tắt/jargon đã có mục trong `THUAT_NGU.md` bị gỡ).

> **Cái KHÔNG kiểm được bằng máy (đã thử, xem "Phương án đã loại"):** quét prose để bắt một viết tắt/jargon **mới lạ chưa định nghĩa**. Với corpus tiếng Việt, chữ HOA nhấn mạnh (`KHÔNG`, `HAI`…) và tên file SCREAMING_SNAKE (`THUAT_NGU.md`) bị `[A-Z]{2,}` băm thành vô số mảnh (`KH`, `NG`, `THUAT`…) — false-positive quá cao. Việc bắt thuật ngữ mới chưa định nghĩa vẫn thuộc **review người + nguyên tắc glossary** (ADR-023). Phần ngữ nghĩa ("prose còn đúng với ADR mới không") cũng vậy.

## ADR-024: Guardrail CI cho quản trị tài liệu (mở rộng ADR-002/021/023)

- **Trạng thái:** Accepted · 2026-06-11 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md), [ADR-021](2026-06-07-ci-spec-design.md), [ADR-023](2026-06-10-quan-tri-tai-lieu-design.md).
- **Bối cảnh:** xem trên.
- **Quyết định:** thêm **một job CI `doc-governance`** (chạy trên MỌI pull request, không gate qua job `changes` — guardrail cần nhất đúng lúc pull request docs-only) chạy **ba script bash native** trong `.github/scripts/`. Cả ba kiểm **trạng thái hiện tại** của repo (không cần diff base...head):

  1. **`check-doc-links.sh`** — sau khi **bỏ code fence (```` ``` ````/`~~~`) + inline code (`` `...` ``)** để không bắt nhầm link ví dụ trong khối code, quét mọi markdown link `[text]\(đích\)` trong **mọi file `.md` tracked của repo** (`git ls-files '*.md'` — gồm `docs/**`, file meta gốc, `.github/**` template, `CHANGELOG.md`); fail nếu **đích là file nội bộ không tồn tại** (giải tương đối theo thư mục file chứa link). Link kiểm rộng (link rot ở đâu cũng bắt), còn `check-doc-map.sh`/`check-glossary-definitions.sh` giữ phạm vi "documentation" (`docs/**` + meta gốc + `THUAT_NGU.md`). Bỏ qua link ngoài (`http(s)://`, `mailto:`, `tel:`). **Anchor `#slug` KHÔNG ép ở v1:** repo có ~113 link theo slug tiêu đề **tiếng Việt** (slugifier sai → red giả) và hiện **0** anchor xuyên file — file-existence là phần giá trị cao, không nhập nhằng.
  2. **`check-doc-map.sh`** — mọi `docs/**/*.md` + file meta gốc phải được `docs/BAN_DO_TAI_LIEU.md` phủ (đường dẫn chính xác **hoặc** glob tiền tố kiểu `docs/superpowers/specs/*`); đồng thời mọi đường dẫn dạng file (`*.md`) hoặc glob (`*/`) liệt kê trong bản đồ phải tồn tại. Bắt: file mới chưa phân loại, đường dẫn ma.
  3. **`check-glossary-definitions.sh` — definition-retention.** Mỗi thuật ngữ trong danh sách canonical (`.github/dictionaries/glossary-terms.txt` — 6 viết tắt + 11 jargon) phải còn **một hàng định nghĩa trong `THUAT_NGU.md`** (hàng bảng có đầu cell là thuật ngữ đó, có/không in đậm). Chống xóa định nghĩa âm thầm. `THUAT_NGU.md` vẫn là nguồn duy nhất chứa *nội dung* định nghĩa; file danh sách chỉ là "lời hứa phải giữ".

  **Trục quyết định kèm theo:**
  - **Hard-fail (đỏ) cho mọi vi phạm** — đỏ = phải sửa; nhất quán với commitlint/branch-source-guard. Theo ADR-007, đỏ chỉ là *tín hiệu* (repo private không có branch protection), kỷ luật một-người-merge tôn trọng.
  - **Chính sách lỗi: fail-loud** (khác `detect-code-changes.sh` fail-safe-to-run). Script lỗi nội bộ → exit khác 0 (đỏ) để người để ý, không âm thầm pass. Mỗi vi phạm in `file + dòng (nếu có) + lý do`.
  - **Portable bash:** dùng `while IFS= read` (không `mapfile` — macOS bash 3.2 không có; khớp `detect-code-changes.sh`), `set -uo pipefail`, để chạy được cả local lẫn ubuntu CI.

  **Một file dữ liệu** (data thuần, không versioned, hỗ trợ dòng comment `#`): `.github/dictionaries/glossary-terms.txt` — 6 viết tắt (CI, ADR, CRUD, UI, SDLC, SemVer) + 11 jargon (distill, merge-back, rollback, release candidate, reslot, supersede, anchor, fail-open, fail-safe, path filter, grooming).

- **Lý do:**
  - Ba dạng drift trên **đo được chắc chắn, không nhập nhằng** → ép bằng máy là đúng ADR-002, mạnh hơn "mong nhớ".
  - Definition-retention thay cho quét prose: giữ được phần **khả thi** (không mất định nghĩa) mà bỏ phần **bất khả thi** (bắt token mới trong tiếng Việt) — không false-positive, không whitelist xấu.
  - Job chạy luôn (không gate) vì guardrail tài liệu cần nhất đúng lúc pull request **chỉ sửa tài liệu** — ngược với job nặng (gate off khi docs-only).
  - Link checker bỏ code trước khi quét vì các plan/spec **nhúng nội dung tài liệu làm ví dụ** trong khối code (kiểm chứng: không bỏ code → 22 "link hỏng" giả; bỏ code → 0).
- **Tradeoff:**
  - (+) Đảm bảo cơ học thật cho link/bản đồ/giữ-định-nghĩa; chống drift tại gốc; nhanh (bash thuần, không Ruby/Postgres); **không false-positive**.
  - (−) **Không** tự bắt viết tắt/jargon *mới lạ* chưa định nghĩa, và **không** ép anchor `#slug` — nêu rõ ở "Giới hạn" để không ai tưởng "đã đảm bảo hết".
  - (−) Thêm 3 script + 1 file dữ liệu để bảo trì; nhỏ, và thay cho "prose rồi mong nhớ".
- **Phương án đã loại:**
  - *Quét prose tìm viết tắt/jargon mới (`[A-Z]{2,}` không thuộc allowlist)* — **loại**: corpus tiếng Việt làm false-positive quá cao (chữ HOA nhấn mạnh + tên file SCREAMING_SNAKE băm thành mảnh `HAI`/`KH`/`NG`/`THUAT`…); whitelist phải nhét ~80–100 mảnh vô nghĩa và vẫn red giả với từ Việt-HOA mới. Hình thức không phân biệt được "HAI" (tiếng Việt) với "JSON" (viết tắt).
  - *Ép anchor `#slug` trong link* — **loại (v1)**: cần slugifier khớp GitHub cho tiếng Việt (~113 anchor); rủi ro red giả cao, lợi ích thấp (0 anchor xuyên file). Để "Điều kiện xem lại".
  - *Chỉ cảnh báo, không đỏ* — loại: yếu "đảm bảo".
  - *Dùng action/linter bên thứ ba* — loại (lúc này): thêm phụ thuộc + cấu hình; bash thuần khớp pattern dự án, đủ dùng, kiểm soát được.
- **Điều kiện xem lại:** cần ép anchor `#slug` → viết slugifier khớp GitHub (tiếng Việt) rồi bật. Nếu sau này tìm được cách bắt viết tắt mới ít nhiễu (vd từ điển tiếng Việt để loại từ thường) → cân nhắc thêm.

## Thiết kế triển khai

Một pull request, nhánh `feature/doc-governance-guardrails` ← `develop`. **Đụng code** (`.github/**`) → CI chạy **full** (không docs-only) → guardrail mới tự kiểm chính nó trên pull request giới thiệu nó.

### Tệp tạo mới (code/data — KHÔNG versioned theo ADR-002)
- `.github/scripts/check-doc-links.sh`, `.github/scripts/check-doc-map.sh`, `.github/scripts/check-glossary-definitions.sh` — bash native, `set -uo pipefail`, `while read` (không `mapfile`), comment tiếng Việt + ADR ref, in vi phạm rõ ràng, exit khác 0 khi vi phạm hoặc lỗi nội bộ.
- `.github/dictionaries/glossary-terms.txt` — danh sách 6 viết tắt + 11 jargon phải giữ định nghĩa; mỗi dòng một mục, dòng `#` là comment.

### Tệp sửa
- `.github/workflows/ci.yml` — thêm job `doc-governance` (`runs-on: ubuntu-latest`, checkout; **không** `needs: changes`), chạy ba script và gom kết quả (không dừng ở lỗi đầu để báo hết vi phạm một lượt; job đỏ nếu bất kỳ script nào đỏ).
- `CONTRIBUTING.md` mục 8 (trạng thái tự động hoá) + `docs/HUONG_DAN_SDLC.md` §5/§8 thêm một dòng về guardrail (bump version + changelog `HUONG_DAN_SDLC.md`).

### Kiểm thử (bash CI script — parity với script hiện có, repo không có framework test bash)
Kiểm bằng: chạy mỗi script trên cây repo hiện tại = **pass** (đã kiểm chứng: 0 link hỏng sau khi bỏ code; bản đồ phủ đủ; 17 thuật ngữ đều có mục). Rồi tạo vi phạm cố ý tạm thời và xác nhận **fail đúng + thông báo đúng**, sau đó hoàn nguyên: (a) thêm link tới file không tồn tại; (b) tạo `docs/zz_tam.md` không cho vào bản đồ; (c) xóa tạm một hàng glossary của thuật ngữ trong danh sách. Plan triển khai ghi từng bước fixture này.

## Giới hạn (không phóng đại "đảm bảo")

Guardrail v1 chỉ ép phần **cơ học, không nhập nhằng**: link file nội bộ sống, bản đồ khớp, 6 viết tắt + 11 jargon giữ định nghĩa. **KHÔNG** đảm bảo: (1) bắt viết tắt/jargon **mới lạ** chưa định nghĩa (bất khả thi cho tiếng Việt — cần mắt người + nguyên tắc glossary ADR-023); (2) anchor `#slug` còn trỏ đúng (hoãn v1); (3) prose còn đúng **ngữ nghĩa** với ADR/nghiệp vụ mới (cần review người — checklist phát hành ở #310); (4) link nằm trong inline code dạng **kép** (``…``) không bị lọc trước khi quét — tránh nhúng link trong span kép (dùng code fence). Mạnh nhất vẫn là **construct tự-không-lỗi-thời** (vd trỏ thư mục thay vì liệt kê `ADR-001..NNN`) — ưu tiên khi viết.

## Truy vết

- **Issue:** [`#313`](https://github.com/manhcuongdtbk/electric-water-management/issues/313) (`change-request`, `documentation`) — `Closes #313` ở pull request.
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-021](2026-06-07-ci-spec-design.md) (pattern CI bash native fail-rõ-ràng), [ADR-023](2026-06-10-quan-tri-tai-lieu-design.md) (bộ quản trị tài liệu mà guardrail này ép). Phụ thuộc: làm sau khi #310 (PR #312) merge.
- **Test:** ba script tự-kiểm trên chính pull request giới thiệu chúng (PR đụng `.github/**` → CI full); kèm fixture vi phạm cố ý trong plan.

## Changelog

- **0.1.1 (2026-06-13):** Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.
- **0.1.0 (2026-06-11):** Bản thảo đầu — ADR-024 (job CI `doc-governance`: 3 check bash native — link chết (bỏ code, file-existence), bản đồ tài liệu khớp, giữ định nghĩa 6 viết tắt + 11 jargon; hard-fail, fail-loud, không false-positive). Đã loại quét-prose-tìm-viết-tắt (bất khả thi cho tiếng Việt) và ép-anchor (hoãn v1) theo kiểm chứng prototype. Mở rộng ADR-002/021/023. Chờ duyệt.
