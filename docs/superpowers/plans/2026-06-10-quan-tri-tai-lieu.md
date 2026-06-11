# Document Governance (ADR-023) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize the project's terminology into one canonical glossary, add a document map, and add an "edit-don't-blindly-append" governance rule — so documentation stops fragmenting and going stale (Issue #310, ADR-023).

**Architecture:** Two new canonical docs (`docs/THUAT_NGU.md` single-source glossary; `docs/BAN_DO_TAI_LIEU.md` document map). Every other doc that used to inline a term/gloss now **points** to `THUAT_NGU.md` instead of duplicating it. A short "Quản trị tài liệu" rule goes into `AGENTS.md`; a one-line "re-check current-state docs" step goes into the release checklist. Docs-only — CI skips the test job (ADR-021).

**Tech Stack:** Markdown only. No code, no automated tests. Verification = `rg`/`grep` assertions that the move happened and no duplicate gloss remains. Branch `feature/document-governance` ← `develop`, squash-merge, `Closes #310`.

**Spec:** `docs/superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md` (already committed in this branch).

**Conventions (from AGENTS.md):** Vietnamese docs, English commits (Conventional Commits), no abbreviations except CI/ADR/CRUD/UI/SDLC/SemVer, spell out "pull request". Versioned `docs/` files bump version + changelog in the same commit; root meta files (`AGENTS.md`, `CONTRIBUTING.md`, `README.md`, `CLAUDE.md`) are NOT versioned. Never rewrite historical/versioned-record docs (old specs/plans/changelog) — only edit current-state docs.

---

### Task 1: Create `docs/THUAT_NGU.md` (canonical glossary — single source)

**Files:**
- Create: `docs/THUAT_NGU.md`

Must be created first because every later task points to it.

- [ ] **Step 1: Write the file with exactly this content**

````markdown
# Thuật ngữ & từ viết tắt — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.0.0
> **Ngày:** 10/06/2026
> **Tính chất:** Nguồn **duy nhất** (canonical) cho định nghĩa thuật ngữ, từ viết tắt và các gloss khái niệm của dự án. Mọi tài liệu khác **trỏ về đây**, không chép lại. Gặp thuật ngữ mới, hoặc thấy một giải thích cũ chưa đủ dễ hiểu → cập nhật ở file này.

Tài liệu dự án dùng **nhất quán** các từ dưới đây. Học một lần, rồi mọi tài liệu khác dùng đúng những từ này (không chế thêm từ đồng nghĩa).

## 1. Từ viết tắt được phép

Quy ước dự án: **tuyệt đối không viết tắt** (xem `AGENTS.md` mục "Nguyên tắc viết"). **Ngoại lệ duy nhất** là các từ dưới đây — đã quá phổ biến, ai cũng hiểu ngay. Cần dùng một từ viết tắt mới → **thêm vào bảng này trước**.

| Viết tắt | Đầy đủ | Nghĩa | Nguồn chính thống |
|---|---|---|---|
| CI | Continuous Integration | Máy chủ tự chạy kiểm tra (test/lint) trên mỗi pull request | [Martin Fowler — Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html) |
| ADR | Architecture Decision Record | Bản ghi một quyết định kiến trúc kèm lý do (trong `docs/superpowers/specs/`) | [adr.github.io](https://adr.github.io/) |
| CRUD | Create, Read, Update, Delete | Bốn thao tác cơ bản với dữ liệu | — |
| UI | User Interface | Giao diện người dùng | — |
| SDLC | Software Development Life Cycle | Vòng đời phát triển phần mềm (quy trình tổng thể) | — |
| SemVer | Semantic Versioning | Quy ước đánh số version `MAJOR.MINOR.PATCH` | [semver.org (tiếng Việt)](https://semver.org/lang/vi/) |

## 2. Thuật ngữ quy trình

| Từ | Nghĩa đời thường |
|---|---|
| **Nhánh** (branch) | Một "đường làm việc" riêng để bạn sửa code mà không đụng người khác. |
| **Commit** | Một lần "lưu" thay đổi, kèm một câu mô tả ngắn. |
| **Push** | Đẩy các commit từ máy bạn lên GitHub. |
| **Merge** | Nhập một nhánh vào nhánh khác (ví dụ nhập việc của bạn vào nhánh chung). Tài liệu dự án luôn gọi là "merge". |
| **Squash** | Một kiểu merge: dồn mọi commit của một pull request thành **một** commit duy nhất cho lịch sử gọn. |
| **Rebase** | Dời các commit của nhánh bạn lên trên một "nền" mới — dùng khi cập nhật nhánh theo `develop` mới nhất, hoặc khi dùng "nhánh xếp chồng" (xem `CONTRIBUTING.md` mục 4). |
| **Pull request** | Lời đề nghị merge nhánh của bạn vào nhánh khác, kèm chỗ để người khác xem và bàn trước khi merge. (Trên GitHub hay viết tắt là "PR"; tài liệu dự án viết đủ "pull request".) |
| **Tag** | Một cái nhãn cố định ghim vào một bản đã phát hành (ví dụ `v1.1.0`). |
| **Issue** | Một phiếu trên GitHub ghi một việc cần làm hoặc một lỗi; có số thứ tự `#N`. |
| **Milestone** | Một nhóm Issue dự kiến cho cùng một bản phát hành (chính là *version đích*). |
| **Version** (số phiên bản) | Số đánh dấu một bản phát hành, theo **SemVer** (mục 1). |
| **Hotfix** | Bản vá **gấp** cho một lỗi *nghiêm trọng* đang chạy thật ở chỗ khách. |
| **Restore** | Khôi phục dữ liệu từ một bản sao lưu. |

> Tên các loại nhánh (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`) được giải thích ở `CONTRIBUTING.md` mục 2 và `docs/HUONG_DAN_SDLC.md` mục 2. Ba nghĩa của "môi trường" (environment): xem `AGENTS.md` mục "Thuật ngữ environment" và `docs/HUONG_DAN_SDLC.md` mục 6.

## 3. Gloss khái niệm

| Khái niệm | Nghĩa |
|---|---|
| **Canonical** | "Nguồn chuẩn gốc" — nơi **duy nhất** định nghĩa một quy ước/fact; mọi nơi khác **trỏ về** chứ không chép lại (để khỏi lệch nhau). `AGENTS.md` là tài liệu canonical cho quy ước dự án; `docs/THUAT_NGU.md` (file này) là canonical cho thuật ngữ. |
| **Chủ dự án** (project owner) | Người chủ trì kho mã: quyết định ưu tiên và là người **duyệt + merge** mọi pull request. Đây là vai trò người phụ trách, *không phải* tính năng "Projects" của GitHub. |

## Lịch sử thay đổi

- **1.0.0 (10/06/2026):** Bản đầu — gom thành nguồn duy nhất: bảng từ viết tắt (chuyển từ `AGENTS.md`), thuật ngữ quy trình (chuyển từ `docs/HUONG_DAN_SDLC.md` §1), gloss "canonical"/"chủ dự án" (gom từ `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`). ADR-023, Issue #310.
````

- [ ] **Step 2: Verify the file has all three sections**

Run: `rg -n "^## 1\. Từ viết tắt được phép|^## 2\. Thuật ngữ quy trình|^## 3\. Gloss khái niệm" docs/THUAT_NGU.md`
Expected: 3 matching lines.

- [ ] **Step 3: Commit**

```bash
git add docs/THUAT_NGU.md
git commit -m "docs: add canonical glossary THUAT_NGU.md

Single source for abbreviations, process vocabulary, and concept
glosses. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Create `docs/BAN_DO_TAI_LIEU.md` (document map)

**Files:**
- Create: `docs/BAN_DO_TAI_LIEU.md`

- [ ] **Step 1: Write the file with exactly this content**

````markdown
# Bản đồ tài liệu — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.0.0
> **Ngày:** 10/06/2026
> **Tính chất:** Canonical — liệt kê mọi tài liệu của dự án kèm **mục đích, đối tượng, loại**, để người và công cụ AI biết **một fact nằm ở đâu** và **sửa ở đâu** thay vì thêm nơi mới. Hỗ trợ trực tiếp quy tắc "sửa đừng thêm" (`AGENTS.md` mục "Quản trị tài liệu"; ADR-023).

## Ba loại tài liệu

- **canonical** — nguồn sự thật cho một fact. Khi một fact sai/cũ → **sửa tại đây**. Mỗi fact chỉ một nơi canonical; nơi khác trỏ về.
- **current-state** — mô tả hiện trạng hoặc dữ liệu suy ra từ canonical (distill, hướng dẫn, kịch bản test). **Phải rà cho khớp** khi canonical/ADR đổi (xem checklist phát hành).
- **lịch sử** — bản ghi quyết định/thời điểm (ADR, plan, changelog). **KHÔNG viết lại**; quyết định mới *supersede* quyết định cũ, giữ nguyên bản cũ.

## Bản đồ

### canonical

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `AGENTS.md` | Quy ước canonical (code + quy trình), mệnh lệnh, trỏ tới chi tiết | Người + mọi công cụ AI |
| `docs/THUAT_NGU.md` | Từ điển thuật ngữ + từ viết tắt + gloss (nguồn duy nhất) | Người + AI |
| `docs/BAN_DO_TAI_LIEU.md` | Bản đồ tài liệu (file này): fact nào ở đâu, loại gì | Người + AI |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ — nguồn sự thật duy nhất cho thiết kế & triển khai | Chủ dự án + đội phát triển |
| `docs/V2_THIET_KE_HE_THONG.md` | Thiết kế hệ thống — nguồn sự thật cho implementation | Đội phát triển |
| `docs/V2_HANH_VI_HE_THONG.md` | Hành vi runtime (6 vai trò, trạng thái kỳ, `.kept`/`.with_discarded`) | Đội phát triển |
| `docs/V2_CHIEU_TEST.md` | 12 chiều kiểm thử, input/output, giao điểm nguy hiểm | Đội phát triển |

### current-state

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `README.md` | Tổng quan, cài đặt, lệnh thường dùng, môi trường | Người mới + đội |
| `CONTRIBUTING.md` | Quy trình làm việc cho người (Git Flow, commit, pair) | Thành viên đội |
| `docs/HUONG_DAN_SDLC.md` | Lối vào onboarding ~15 phút: vòng đời một thay đổi + bảng tra cứu | Thành viên mới |
| `docs/HUONG_DAN_DEPLOY.md` | Hướng dẫn deploy production (thao tác từng bước) | Người thực hiện deploy |
| `docs/KIEN_THUC_DOCKER.md` | Kiến thức + cấu hình Docker ở mọi môi trường | Developer + người vận hành |
| `docs/hdsd/V2_HUONG_DAN_SU_DUNG.md` | Hướng dẫn sử dụng cho người dùng cuối | Người dùng hệ thống |
| `docs/V2_KICH_BAN_TEST.md` | Kịch bản kiểm thử (số liệu cụ thể) — suy ra từ bốn tài liệu nguồn, tái sinh khi nguồn đổi | Đội phát triển |

### lịch sử

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `docs/superpowers/specs/*` | Spec + ADR: quyết định kèm lý do (supersede, không viết lại) | Người + AI |
| `docs/superpowers/plans/*` | Plan triển khai từng việc (bản ghi thời điểm) | Người + AI thực thi |
| `CHANGELOG.md` | Lịch sử phát hành sinh tự động (release-please) | Người + khách |

> `CLAUDE.md` chỉ chứa dòng `@AGENTS.md` (import shim để Claude Code đọc `AGENTS.md`) — không phải nguồn fact riêng. `version.txt` do release-please sinh, không phải tài liệu.

## Lịch sử thay đổi

- **1.0.0 (10/06/2026):** Bản đầu — phân loại canonical / current-state / lịch sử cho toàn bộ tài liệu dự án. ADR-023, Issue #310.
````

- [ ] **Step 2: Verify the three type sections exist**

Run: `rg -n "^### canonical|^### current-state|^### lịch sử" docs/BAN_DO_TAI_LIEU.md`
Expected: 3 matching lines.

- [ ] **Step 3: Commit**

```bash
git add docs/BAN_DO_TAI_LIEU.md
git commit -m "docs: add document map BAN_DO_TAI_LIEU.md

Classifies every project doc as canonical / current-state / historical
so contributors know where to edit a fact. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Update `AGENTS.md` — point to glossary, add governance rule

**Files:**
- Modify: `AGENTS.md` (header line 3; "Nguyên tắc viết" section; new "Quản trị tài liệu" section; "Tài liệu liên quan")

Root meta file — **not versioned**, no changelog.

- [ ] **Step 1: Trim the inline "canonical" gloss in the header to a pointer**

Replace (currently line 3):
```
> **Nguồn canonical** (nguồn chuẩn gốc — nơi duy nhất định nghĩa quy ước; mọi nơi khác trỏ về đây thay vì chép lại, để khỏi lệch nhau) cho mọi quy ước của dự án (code + quy trình), dùng chung cho cả người và mọi công cụ AI (Claude Code, Cursor, Copilot, Codex, Gemini, VS Code…).
```
With:
```
> **Nguồn canonical** (định nghĩa "canonical": `docs/THUAT_NGU.md`) cho mọi quy ước của dự án (code + quy trình), dùng chung cho cả người và mọi công cụ AI (Claude Code, Cursor, Copilot, Codex, Gemini, VS Code…).
```

- [ ] **Step 2: Replace the "Nguyên tắc viết" paragraph + abbreviation table with a pointer**

Replace the whole block — the paragraph starting `Tuyệt đối không viết tắt` AND the markdown table beneath it (the table rows for CI/ADR/CRUD/UI/SDLC/SemVer, ending at the SemVer row) — with this single paragraph:
```
Tuyệt đối không viết tắt, không rút gọn — áp dụng mọi nơi: tài liệu, code (tên biến, method, cột, i18n, commit message), giao diện, giao tiếp. **Ngoại lệ duy nhất** là các từ viết tắt liệt kê trong `docs/THUAT_NGU.md` (đã quá phổ biến, ai cũng hiểu ngay). Cần dùng một từ viết tắt mới → **thêm vào `docs/THUAT_NGU.md` trước** (đó là danh sách canonical duy nhất). Thuật ngữ và gloss khái niệm cũng tra/cập nhật tại `docs/THUAT_NGU.md`.
```

- [ ] **Step 3: Insert a new "Quản trị tài liệu" section right after "Nguyên tắc viết"**

Insert immediately before the line `## Tài liệu nguồn (đọc trước khi làm bất cứ gì)`:
```
## Quản trị tài liệu (sửa đừng thêm)

- Trước khi cập nhật tài liệu: **đọc lại toàn file và đối chiếu** xem fact đã có chỗ chưa. Thêm hay sửa là **tùy kết quả đánh giá** — đã có thì sửa/tích hợp tại chỗ; thực sự mới thì thêm vào đúng nơi canonical. Cái cần tránh là **"append mù"** (dán thêm khi chưa đọc) tạo trùng lặp/mâu thuẫn.
- Mỗi fact chỉ **một nơi canonical**; nơi khác **trỏ về**, không chép. Không chắc fact thuộc file nào → tra `docs/BAN_DO_TAI_LIEU.md` (mỗi tài liệu + mục đích + đối tượng + loại canonical/current-state/lịch sử) để biết chỗ để **sửa** thay vì thêm nơi mới.
- Thuật ngữ và từ viết tắt: nguồn duy nhất là `docs/THUAT_NGU.md`. Gặp thuật ngữ mới hoặc thấy giải thích cũ chưa đủ rõ → cập nhật ở đó.
- Quyết định & lý do đầy đủ: ADR-023 trong `docs/superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md` (mở rộng ADR-002).

```

- [ ] **Step 4: Add two entries to "Tài liệu liên quan"**

In the `## Tài liệu liên quan` list, insert these two bullets immediately after the `- `CONTRIBUTING.md` — quy trình đóng góp cho người.` line:
```
- `docs/THUAT_NGU.md` — từ điển thuật ngữ + từ viết tắt + gloss (nguồn duy nhất).
- `docs/BAN_DO_TAI_LIEU.md` — bản đồ tài liệu (fact nào ở file nào, loại gì).
```

- [ ] **Step 5: Verify the abbreviation table is gone from AGENTS.md and the new section exists**

Run: `rg -n "martinfowler.com|^## Quản trị tài liệu|THUAT_NGU" AGENTS.md`
Expected: NO `martinfowler.com` line (table moved out); `## Quản trị tài liệu` present; at least 3 `THUAT_NGU` references.

- [ ] **Step 6: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): point glossary to THUAT_NGU and add document-governance rule

Move the allowed-abbreviation table to docs/THUAT_NGU.md (single
source), keep an imperative rule pointing there, and add an
edit-don't-blindly-append section referencing the document map. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Update `CONTRIBUTING.md` — replace inline "canonical" gloss with pointer

**Files:**
- Modify: `CONTRIBUTING.md` (line 3)

Root meta file — **not versioned**, no changelog.

- [ ] **Step 1: Replace the inline gloss with a pointer**

Replace (currently line 3):
```
Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` (nguồn canonical — nguồn chuẩn gốc của quy ước; nơi khác trỏ về đây, không chép lại). Quyết định kèm lý do nằm trong `docs/superpowers/specs/`. Người mới nên đọc `docs/HUONG_DAN_SDLC.md` trước cho dễ vào.
```
With:
```
Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` — tài liệu [canonical](docs/THUAT_NGU.md) của dự án. Quyết định kèm lý do nằm trong `docs/superpowers/specs/`. Người mới nên đọc `docs/HUONG_DAN_SDLC.md` trước cho dễ vào. Thuật ngữ và từ viết tắt: tra `docs/THUAT_NGU.md`.
```

- [ ] **Step 2: Verify the inline gloss phrase is gone**

Run: `rg -n "nguồn chuẩn gốc" CONTRIBUTING.md`
Expected: NO match (gloss removed; only `THUAT_NGU` link remains — confirm with `rg -n "THUAT_NGU" CONTRIBUTING.md`).

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs(contributing): replace inline canonical gloss with THUAT_NGU pointer

Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Update `docs/HUONG_DAN_SDLC.md` — vocabulary → pointer, bump version

**Files:**
- Modify: `docs/HUONG_DAN_SDLC.md` (§1 vocabulary; §8 abbreviation pointer; §5 lookup table row; "Cần chi tiết hơn?" ADR range; version header + changelog)

Versioned `docs/` file — **bump `1.0.0` → `1.1.0` + changelog in the same commit** (ADR-002).

- [ ] **Step 1: Replace the entire "## 1. Từ vựng" section with a pointer**

Replace everything from the line `## 1. Từ vựng (đọc cái này trước)` up to (but NOT including) the line `## 2. Mô hình nhánh: Git Flow` with:
```
## 1. Từ vựng (đọc cái này trước)

Thuật ngữ, từ viết tắt và các gloss ("canonical", "chủ dự án"…) dùng trong dự án nằm tập trung ở **[`docs/THUAT_NGU.md`](THUAT_NGU.md)** — nguồn **duy nhất**, học một lần dùng mọi nơi. Đọc lướt mục đó trước khi đọc tiếp.

(Tên các loại nhánh `develop`, `main`, `feature/*`, `release/*`, `hotfix/*` được giải thích ngay ở mục 2.)

```

- [ ] **Step 2: Update the abbreviation pointer in §8 to point at THUAT_NGU**

Replace (in the "## 8. Quy ước sống còn" list):
```
- **Không viết tắt**, trừ các từ trong bảng *"Từ viết tắt được phép"* ở [AGENTS.md](../AGENTS.md) (hiện gồm CI, ADR, CRUD, UI, SDLC, SemVer). Cần thêm từ viết tắt mới → thêm vào bảng đó trước.
```
With:
```
- **Không viết tắt**, trừ các từ trong bảng *"Từ viết tắt được phép"* ở [`docs/THUAT_NGU.md`](THUAT_NGU.md) (hiện gồm CI, ADR, CRUD, UI, SDLC, SemVer). Cần thêm từ viết tắt mới → thêm vào bảng đó trước.
```

- [ ] **Step 3: Add a "Quản trị tài liệu" row to the §5 lookup table**

In the table under `## 5. Bảng tra cứu nhanh`, insert this row immediately BEFORE the existing row that starts with `| Tài liệu | File trong `docs/` có dòng *Phiên bản*`:
```
| Quản trị tài liệu | Mỗi fact một nơi canonical, nơi khác trỏ về; sửa đừng "append mù"; thuật ngữ ở `THUAT_NGU.md`, loại tài liệu ở `BAN_DO_TAI_LIEU.md` | [THUAT_NGU](THUAT_NGU.md) · [BAN_DO_TAI_LIEU](BAN_DO_TAI_LIEU.md) · [ADR-023](superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md) |
```

- [ ] **Step 4: Update the ADR range in "Cần chi tiết hơn?"**

Replace:
```
- [docs/superpowers/specs/](superpowers/specs/) — **quyết định kèm lý do** (ADR-001..022).
```
With:
```
- [docs/superpowers/specs/](superpowers/specs/) — **quyết định kèm lý do** (ADR-001..023).
```

- [ ] **Step 5: Bump version header and date**

Replace:
```
> **Phiên bản:** 1.0.0
> **Ngày:** 09/06/2026
```
With:
```
> **Phiên bản:** 1.1.0
> **Ngày:** 10/06/2026
```

- [ ] **Step 6: Add a changelog entry**

In the `## Lịch sử thay đổi` list, insert this as the FIRST (top) bullet, above the `- **1.0.0 (09/06/2026):**` line:
```
- **1.1.0 (10/06/2026):** §1 "Từ vựng" gom về [`docs/THUAT_NGU.md`](THUAT_NGU.md) (nguồn duy nhất), thay bảng bằng pointer; §8 trỏ từ viết tắt sang `THUAT_NGU.md`; §5 thêm dòng "Quản trị tài liệu"; cập nhật dải ADR-001..023. ADR-023, Issue #310.
```

- [ ] **Step 7: Verify the vocabulary table is gone and pointers are in place**

Run: `rg -n "Nghĩa đời thường|Phiên bản:|THUAT_NGU|ADR-001\.\.0?23" docs/HUONG_DAN_SDLC.md`
Expected: NO `Nghĩa đời thường` line (table moved out); `> **Phiên bản:** 1.1.0`; several `THUAT_NGU` references; `ADR-001..023`.

- [ ] **Step 8: Commit**

```bash
git add docs/HUONG_DAN_SDLC.md
git commit -m "docs(sdlc): centralize vocabulary to THUAT_NGU and add governance lookup row

Replace HUONG_DAN_SDLC vocabulary table with a pointer to the single
glossary, repoint the abbreviation note, add a document-governance
lookup row. Bump 1.0.0 -> 1.1.0. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Update release spec — add doc re-check to the release checklist

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (checklist; version `0.13.0` → `0.14.0`; changelog)

Versioned spec — **bump + changelog in the same commit**. This is the *current* checklist (an executable list), not a historical decision, so editing it is correct.

- [ ] **Step 1: Add the re-check line to "## Checklist phát hành"**

In the `## Checklist phát hành (thực thi, vẫn duyệt tay)` list, insert this line immediately after the `- [ ] `/code-review` local không còn cảnh báo nghiêm trọng.` line:
```
- [ ] Rà tài liệu current-state khớp ADR mới nhất (xem bản đồ tài liệu `docs/BAN_DO_TAI_LIEU.md`).
```

- [ ] **Step 2: Bump the frontmatter version**

Replace `version: 0.13.0` with `version: 0.14.0` in the YAML frontmatter.

- [ ] **Step 3: Add a changelog entry**

In the `## Changelog` list, insert this as the FIRST (top) bullet:
```
- **0.14.0 (2026-06-10):** Checklist phát hành thêm bước "Rà tài liệu current-state khớp ADR mới nhất" (ADR-023 — quản trị tài liệu; Issue #310).
```

- [ ] **Step 4: Verify**

Run: `rg -n "Rà tài liệu current-state|^version: 0.14.0|0\.14\.0 \(2026-06-10\)" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`
Expected: 3 matching lines.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
git commit -m "docs(sdlc): add current-state doc re-check to release checklist

Bump release spec 0.13.0 -> 0.14.0. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Update SDLC overview spec — note ADR-002 is extended by ADR-023

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` (ADR-002 status line; version `0.2.0` → `0.3.0`; changelog)

Versioned spec — **bump + changelog in the same commit**. We only ADD a cross-reference note to ADR-002 (we do NOT rewrite the decision itself).

- [ ] **Step 1: Add the "extended by ADR-023" note to ADR-002's status line**

Under `## ADR-002:`, replace:
```
- **Trạng thái:** Proposed · 2026-06-07
```
With:
```
- **Trạng thái:** Proposed · 2026-06-07 · **mở rộng bởi [ADR-023](2026-06-10-quan-tri-tai-lieu-design.md)** (quản trị tài liệu: từ điển thuật ngữ + bản đồ tài liệu + quy tắc "sửa đừng thêm").
```

- [ ] **Step 2: Bump the frontmatter version**

Replace `version: 0.2.0` with `version: 0.3.0` in the YAML frontmatter.

- [ ] **Step 3: Add a changelog entry**

In the `## Changelog` list, insert this as the FIRST (top) bullet, above the `- **0.2.0 (2026-06-07):**` line:
```
- **0.3.0 (2026-06-10):** ADR-002 ghi chú được **mở rộng bởi ADR-023** (quản trị tài liệu — spec `2026-06-10-quan-tri-tai-lieu-design.md`; Issue #310).
```

- [ ] **Step 4: Verify**

Run: `rg -n "mở rộng bởi \[ADR-023\]|^version: 0.3.0|0\.3\.0 \(2026-06-10\)" docs/superpowers/specs/2026-06-07-sdlc-overview-design.md`
Expected: at least 3 matching lines (the ADR-002 note, the frontmatter version, the changelog entry).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-sdlc-overview-design.md
git commit -m "docs(sdlc): note ADR-002 is extended by ADR-023

Bump SDLC overview 0.2.0 -> 0.3.0. Refs #310

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Cross-file verification, push, open pull request

**Files:** none (verification + git)

- [ ] **Step 1: Confirm no duplicate "canonical" gloss survives outside THUAT_NGU.md**

Run: `rg -n "nguồn chuẩn gốc" -g '!docs/superpowers/plans/**'`
Expected: matches ONLY in `docs/THUAT_NGU.md` (the canonical gloss). No hits in `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`.

- [ ] **Step 2: Confirm the abbreviation source links live only in THUAT_NGU.md**

Run: `rg -ln "martinfowler.com/articles/continuousIntegration"`
Expected: ONLY `docs/THUAT_NGU.md`.

- [ ] **Step 3: Confirm every pointer target exists**

Run: `ls docs/THUAT_NGU.md docs/BAN_DO_TAI_LIEU.md docs/superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md`
Expected: all three listed, no error.

- [ ] **Step 4: Review the full diff against `develop`**

Run: `git fetch origin develop && git diff --stat origin/develop...HEAD`
Expected (files changed): the spec + plan (already committed) + `docs/THUAT_NGU.md`, `docs/BAN_DO_TAI_LIEU.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`, `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`, `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md`. Docs/meta only — no code files.

- [ ] **Step 5: Integrate base if behind, then push (only after project-owner approval)**

Run: `git log --oneline origin/develop ^HEAD` — if non-empty, the branch is behind; integrate with `git merge origin/develop` (resolve any conflict) before pushing. Then: `git push -u origin feature/document-governance`.

- [ ] **Step 6: Open the pull request**

```bash
gh pr create --base develop --head feature/document-governance \
  --title "docs: centralize terminology and add lightweight document governance (ADR-023)" \
  --body "$(cat <<'EOF'
## Summary
Implements Issue #310 (ADR-023): lightweight document governance.

- Add `docs/THUAT_NGU.md` — single canonical source for abbreviations, process vocabulary, and concept glosses.
- Add `docs/BAN_DO_TAI_LIEU.md` — document map classifying every doc as canonical / current-state / historical.
- `AGENTS.md`: move the allowed-abbreviation table to THUAT_NGU (pointer + rule kept); add a "Quản trị tài liệu" (edit-don't-blindly-append) section.
- `CONTRIBUTING.md` + `docs/HUONG_DAN_SDLC.md`: replace duplicated "canonical"/vocabulary with pointers to THUAT_NGU.
- Release checklist: add "re-check current-state docs against latest ADRs".
- Spec `2026-06-10-quan-tri-tai-lieu-design.md` (ADR-023, extends ADR-002).

## Acceptance criteria (Issue #310)
- [x] One single terminology source (`docs/THUAT_NGU.md`); other docs point to it.
- [x] Document map classifying canonical / current-state / historical.
- [x] `AGENTS.md` has the edit-don't-blindly-append rule + glossary pointer; release checklist has the doc re-check step.
- [x] ADR-023 written (with rationale; extends ADR-002).

Docs-only — CI test job skipped by path filter (ADR-021).

Closes #310
EOF
)"
```

- [ ] **Step 7: Monitor CI and report**

Run: `gh pr checks --watch` (or per the repo's CI-monitor hook). Report pass/fail to the project owner. Docs-only change → expect the static checks to pass and the test job to be skipped.

---

## Self-Review

**Spec coverage** (against `2026-06-10-quan-tri-tai-lieu-design.md`):
- THUAT_NGU.md (abbreviations + vocabulary + glosses) → Task 1. ✅
- BAN_DO_TAI_LIEU.md (3-type map) → Task 2. ✅
- AGENTS.md pointer + "sửa đừng thêm" rule → Task 3. ✅
- CONTRIBUTING.md gloss → pointer → Task 4. ✅
- HUONG_DAN_SDLC §1/§8/§5 + bump → Task 5. ✅
- Release checklist line + bump → Task 6. ✅
- ADR-002 "extended by ADR-023" note + bump → Task 7. ✅
- `Closes #310`, docs-only CI → Task 8. ✅

**Placeholder scan:** No TBD/TODO; every step shows exact content or exact command. ✅

**Consistency:** Pointer target `docs/THUAT_NGU.md` is created in Task 1 before any task references it. Links inside `docs/` use same-directory relative paths (`THUAT_NGU.md`), root meta files use `docs/THUAT_NGU.md`. Version deltas match real current values (HUONG_DAN_SDLC 1.0.0→1.1.0, release 0.13.0→0.14.0, overview 0.2.0→0.3.0). `V2_KICH_BAN_TEST.md` classified current-state (derived), consistent with the spec. ✅
