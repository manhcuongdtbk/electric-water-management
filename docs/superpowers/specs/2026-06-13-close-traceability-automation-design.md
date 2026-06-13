---
title: Tự động khép dấu vết khi đóng issue (comment kết post-merge + reconcile milestone copy-only)
version: 0.1.0
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Tự động khép dấu vết khi đóng issue

Ép **máy** phần cơ học của việc "khép dấu vết khi đóng issue" để không còn phụ thuộc người/AI nhớ làm. Phát hiện khi đóng [`#328`](https://github.com/manhcuongdtbk/electric-water-management/issues/328): comment cuối trên issue là bản *trước-merge* ("PR sẽ `Closes #N` khi merge"), phải bổ sung comment kết **thủ công** sau khi merge — và nhiều closed issue cũ thiếu hẳn comment kết / milestone. Đúng tinh thần [ADR-029](2026-06-07-sdlc-overview-design.md) (máy lo cơ học, người giữ phán đoán) và [ADR-002](2026-06-07-sdlc-overview-design.md) (luật nào máy ép được thì để máy ép).

**Ràng buộc cốt lõi định hình thiết kế:** `Closes #N` tự đóng issue như *hệ quả của merge* — KHÔNG có sự kiện "CI on issue-close" để chặn trước. Điểm ép phải **dời sang PR** (sự kiện `pull_request: closed`) + tự động hóa **hậu-merge**, không phải gate trên issue.

## Bối cảnh

Quy ước truy vết hiện hành ([ADR-013..015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)): GitHub Issue mang luồng yêu cầu, repo mang dấu vết (spec/PR/commit), issue đóng khi PR mang `Closes #N` merge. Phần "khép" — xác nhận thực-tế-đã-ship + reconcile milestone/label — đang là **thói quen thủ công**, đã được ghi thành feedback vận hành nhưng vẫn lệ thuộc trí nhớ.

Ba lớp tự động hóa có mức khả thi khác nhau (nêu trong [`#342`](https://github.com/manhcuongdtbk/electric-water-management/issues/342)):

1. **Comment kết post-merge** — cơ học thuần, rủi ro thấp. Máy ghép PR#/SHA/base → một comment chuẩn. Đáng làm.
2. **Reconcile milestone** — có vùng xung đột với **gate triage** ([ADR-019/020](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md)): nhiều `fix` merge *trước* khi triage milestone (chính `#328` cố ý để trống milestone chờ triage). Ép "PR phải có milestone mới merge" sẽ phá gate đó.
3. **Nội dung phán đoán** (sai khác plan, caveat, chiều test đã phủ) — máy KHÔNG sinh được; để người/AI làm giàu. Ngoài phạm vi tự động.

Triage `#342` (gate chủ dự án, [ADR-019/020](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md)): milestone `1.2.0` (khớp các guardrail process gần đây `#329`/`#339`), **không** `priority-high` (tooling, không phải tính năng khách → không gác release). Quy ước chốt qua brainstorm (session 2026-06-13).

Không đụng nghiệp vụ ứng dụng (`docs/V2_XAC_NHAN_NGHIEP_VU.md` không liên quan) — thuần tooling/CI.

## Quyết định (ADR)

### ADR-035: Tự động khép dấu vết hậu-merge (comment kết + milestone copy-only), điểm ép dời sang PR

- **Trạng thái:** Accepted · 2026-06-13 · mở rộng [ADR-013..015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) (truy vết thay đổi), [ADR-029](2026-06-07-sdlc-overview-design.md) (máy lo cơ học, người giữ phán đoán); theo pattern [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (CI bash fail-loud) và [ADR-011](2026-06-07-quy-trinh-release-design.md) (guard đọc event qua biến môi trường).
- **Bối cảnh:** xem trên — khép dấu vết là thủ công, dễ quên; `Closes #N` đóng issue như hệ quả merge nên không chặn được ở issue.
- **Quyết định:**
  1. **Workflow mới `close-traceability.yml`**, `on: pull_request: types: [closed]`, gate `if: github.event.pull_request.merged == true` (chỉ chạy khi PR thực sự merge, không phải đóng-không-merge). `permissions: { issues: write, contents: read, pull-requests: read }`. Dùng `GITHUB_TOKEN` mặc định — mọi PR là **same-repo** (Git Flow, không fork) nên KHÔNG cần `pull_request_target` (tránh bề mặt bảo mật của event đó).
  2. **Lớp 1 — comment kết (cơ học).** Script parse closing-keyword GitHub (`close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved` theo sau `#<số>`, same-repo) trong **body PR**. Mỗi issue khớp → post một comment chuẩn (mẫu dưới), **gọn**: PR# + tiêu đề, merge SHA (ngắn + đầy đủ), nhánh đích, thời điểm merge (Asia/Ho_Chi_Minh), dòng trạng thái milestone. KHÔNG kèm danh sách commit (squash = một commit = chính PR) hay kết quả check (đã chạy trên PR, không phải ở đây). PR chỉ có `Refs #N` (không phải closing-keyword) → **không** comment (issue không đóng).
  3. **Lớp 2 — reconcile milestone = COPY-ONLY.** Nếu PR có milestone và issue **chưa** có → copy PR→issue. **Không bao giờ** ghi đè milestone issue đã có; **không** chặn; **không** cảnh báo PR-time. Khi cả hai đều trống (đúng tình huống `#328`) → máy **no-op**, triage vẫn sở hữu quyết định. Triệt xung đột với gate triage ([ADR-019/020](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md)).
  4. **Lớp 3 (phán đoán) — ngoài phạm vi.** Comment cơ học mang marker tự-nhận-diện và một dòng mời người/AI bổ sung nhận định khi có nuance.
  5. **Idempotency:** mỗi comment mở đầu bằng marker ẩn `<!-- auto-close-traceability:pr-<số> -->`. Trước khi post, quét comment issue tìm marker của đúng PR đó → đã có thì bỏ qua (re-run workflow không nhân bản).
  6. **Best-effort + fail-loud cuối.** Xử lý từng issue độc lập; lỗi `gh` ở một issue ghi cảnh báo nhưng vẫn xử issue khác. Cuối script `exit 1` nếu có bất kỳ thao tác lỗi → workflow đỏ để được chú ý (thói quen theo dõi CI). Vì là hậu-merge, đỏ KHÔNG chặn gì — chỉ để lộ lỗi.
  7. **Forward-only.** Không hồi tố. Backfill một-lần các closed issue cũ đã hoàn tất ở session trước — ngoài phạm vi ADR này.
- **Lý do:**
  - **Điểm ép ở PR, không ở issue:** đúng cơ chế GitHub (issue đóng là hệ quả merge, không có sự kiện chặn) — giống [ADR-029](2026-06-07-sdlc-overview-design.md) dời cơ học về nơi máy can thiệp được.
  - **Milestone copy-only (không block/không warn):** giữ trọn gate triage. Block phá luồng `fix`-merge-trước-triage; warn PR-time vô dụng vì `ci.yml` cố ý KHÔNG nghe trigger `edited` (sửa milestone sau khi mở PR sẽ không re-evaluate). Copy-only chỉ hành động khi thông tin đã tồn tại → thuần cơ học, không phán đoán.
  - **Comment gọn:** đủ khép "đã ship gì" làm baseline; commit-list/checks là nhiễu (squash một commit; checks thuộc PR).
  - **Bash + `gh` fail-loud:** nhất quán pattern guardrail ([ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md)); `gh` có sẵn trên runner; logic parse/render tách hàm thuần test offline được (companion `.test.sh` như ADR-031/032/033).
- **Tradeoff:**
  - (+) Mọi PR `Closes #N` merge → issue tự nhận comment kết baseline; không còn quên.
  - (+) Milestone tự lấp khi PR đã có, mà không đụng gate triage.
  - (+) Phán đoán vẫn ở người/AI — không sinh nội dung sai/giả tin cậy.
  - (−) Thêm 1 workflow + 1 script + 1 companion test bảo trì.
  - (−) Comment cơ học không phán đoán; nếu người quên bổ sung nuance, dấu vết vẫn chỉ ở mức "đã ship gì" (chấp nhận — vẫn hơn trống).
  - (−) Lớp 2 không lấp được milestone khi cả PR lẫn issue đều trống — cố ý nhường triage.
- **Phương án đã loại:**
  - *Block: PR phải có milestone mới merge* — loại: phá gate triage ([ADR-019/020](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md)); `#328` cố ý để trống chờ triage.
  - *Warn-only PR-time* — loại: `ci.yml` không nghe `edited` → thêm milestone sau khi mở PR không re-evaluate; cảnh báo lệch thời điểm, ít giá trị.
  - *Comment giàu (commit-list + checks)* — loại: nhiễu; squash một commit, checks thuộc PR.
  - *Gộp vào guardrail hiện có, không ADR* — loại: đây là bề mặt tự động hóa **mới** (workflow on PR-close, post nội dung lên issue) + một lựa chọn policy (copy-not-block) — xứng một ADR ngắn để ghi lý do.
  - *Sinh cả phán đoán tự động* — loại: máy không suy luận được sai-khác-plan/caveat; sinh ra dễ sai và tạo cảm giác tin cậy giả.
  - *`pull_request_target` để chạy* — loại: không cần (không fork); event đó mở bề mặt bảo mật (chạy code base với token ghi) không đáng.
- **Điều kiện xem lại:**
  - Nếu chuyển sang chấp nhận PR từ fork (đóng góp ngoài) → xem lại token/permission và cân nhắc `pull_request_target` có kiểm soát.
  - Nếu thực tế cần ép milestone cứng hơn (ví dụ release-readiness gate) → mở lại lớp 2 với policy block/warn có điều kiện.
  - Nếu mẫu comment cần thêm trường (ví dụ link release) → cập nhật hàm render + companion test.

## Thiết kế triển khai

Một pull request, nhánh `ci/close-traceability-automation` ← `develop`. Commit dạng `ci`. Đụng `.github/**` + `docs/**`; guardrail doc-governance hiện có tự kiểm spec này (đã tính link/map/changelog-header).

### Tệp tạo mới

- `.github/workflows/close-traceability.yml` — workflow `pull_request: closed` + gate `merged == true`. Một job, một bước chạy script; truyền field PR qua biến môi trường (số PR, body, merge SHA, base ref, milestone title, merged_at) + `GH_TOKEN`.
- `.github/scripts/post-close-traceability.sh` — orchestrator. Bash thuần `set -uo pipefail`. Hàm thuần tách riêng (test được): `extract_issue_numbers` (body → danh sách số issue, khử trùng), `render_comment` (các field → markdown comment kèm marker). Phần I/O `gh` (đọc milestone issue, edit milestone, view comments tìm marker, post comment) ở nhánh thực thi, **chỉ chạy khi script được gọi trực tiếp** (guard `${BASH_SOURCE[0]} == ${0}` / biến cờ) để companion `source` được mà không chạm mạng. Comment tiếng Việt (issue thread team); echo/log **tiếng Anh** (output kỹ thuật CI).
- `.github/scripts/post-close-traceability.test.sh` — companion người-chạy (không wire CI), fixture tạm, không gọi `gh`. Ca tối thiểu: `extract_issue_numbers` cho `Closes #12`, `Fixes #3, closes #4` (đa issue + khử trùng), `Resolved #9`, body chỉ `Refs #7` → rỗng, `#7` trần (không keyword) → rỗng; `render_comment` chứa marker đúng PR + các field; (tùy chọn) dòng milestone đổi theo có/không milestone.

### Tệp sửa

- `CONTRIBUTING.md` §8 — một đoạn "Tự động khép dấu vết khi đóng issue (ADR-035)" (kiểu các đoạn ADR-024/030/032/033): mô tả workflow hậu-merge, comment cơ học vs phán đoán-người, milestone copy-only. **File meta, không versioned.**

### Mẫu comment kết (gọn, tiếng Việt)

```
<!-- auto-close-traceability:pr-123 -->
## Khép dấu vết (tự động) — đã merge

- **Pull request:** #123 — <tiêu đề PR>
- **Merge commit:** `a1b2c3d` (`<SHA đầy đủ>`)
- **Nhánh đích:** `develop`
- **Thời điểm merge:** 2026-06-13 21:40 (Asia/Ho_Chi_Minh)
- **Milestone:** 1.2.0    ← hoặc "— (chưa gán, chờ triage)"

> Comment cơ học (ADR-035): xác nhận "đã ship gì". Phần nhận định (sai khác
> plan, caveat, chiều test đã phủ) do người/AI bổ sung khi có nuance.
```

### Không đụng (cố ý)

- `ci.yml` — không thêm job vào đó (workflow này nghe sự kiện khác: `closed` thay vì `opened/synchronize/reopened`).
- Lớp 3 (phán đoán) — không tự sinh.
- Hồi tố các closed issue cũ — đã backfill session trước.
- PR đích `main` (release/hotfix) — thường không mang `Closes #N` nên no-op tự nhiên; không xử lý đặc biệt.

## Kiểm thử

Theo kiểu ADR-024/030/032/033:

- **Companion `.test.sh`** (người chạy): các ca `extract_issue_numbers` + `render_comment` ở trên — chạy `bash .github/scripts/post-close-traceability.test.sh`, kỳ vọng xanh.
- **Kiểm chứng workflow thật** (ghi trong plan): trên một PR thử nghiệm có `Closes #<issue-nháp>` → sau merge, issue nhận đúng một comment kết có marker; chạy lại workflow (re-run) → KHÔNG nhân bản (idempotency). PR có milestone, issue chưa → milestone được copy. PR chỉ `Refs #N` → không comment.
- Guardrail doc-governance + i18n-view vẫn xanh trên PR này. `bin/docker rspec` không liên quan (không đụng app/spec Ruby).

## Giới hạn (không phóng đại "đảm bảo")

Tự động hóa **chỉ** đảm bảo: PR merge mang closing-keyword `#N` → issue `#N` nhận đúng một comment kết cơ học (idempotent) và, nếu PR có milestone còn issue chưa, milestone được copy. **KHÔNG** đảm bảo:

1. **Dấu vết đầy đủ về phán đoán** — comment chỉ ghép field cơ học; sai-khác-plan/caveat/chiều-test do người/AI bổ sung (lớp 3, ngoài phạm vi).
2. **Mọi issue đều có milestone** — copy-only; cả PR lẫn issue trống thì máy no-op (nhường triage). Không lấp khoảng trống triage.
3. **Đóng đúng issue** — máy tin closing-keyword trong body PR; gõ nhầm số issue ở body → comment sai chỗ (như chính `Closes #N` của GitHub cũng đóng nhầm — không tệ hơn hiện trạng).
4. **PR từ fork** — thiết kế giả định same-repo (Git Flow, không fork); fork sẽ cần xem lại token/permission (điều kiện xem lại).

## Truy vết

- **Issue:** [`#342`](https://github.com/manhcuongdtbk/electric-water-management/issues/342) (`change-request`, milestone `1.2.0`, không `priority-high`) → **`Closes #342`** (đây là toàn bộ nội dung #342).
- **Lên:** [ADR-013..015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) (truy vết thay đổi), [ADR-029](2026-06-07-sdlc-overview-design.md) (máy lo cơ học, người giữ phán đoán), [ADR-019/020](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md) (gate triage — lý do milestone copy-only), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern bash fail-loud), [ADR-011](2026-06-07-quy-trinh-release-design.md) (đọc event qua biến môi trường).
- **Bài học gốc:** [`#328`](https://github.com/manhcuongdtbk/electric-water-management/issues/328) (comment kết phải bổ sung thủ công sau merge).
- **Test:** companion `post-close-traceability.test.sh` + kiểm chứng workflow thật (ghi trong plan). Không có chiều test app (tooling thuần) → không bảng `## Truy vết chiều test` (ADR-030 chỉ áp khi có chiều test).

## Lịch sử thay đổi

- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-035 (tự động khép dấu vết hậu-merge). Workflow `close-traceability.yml` nghe `pull_request: closed` + gate `merged`; lớp 1 comment kết cơ học gọn (PR#/SHA/base/merged_at/milestone) idempotent qua marker ẩn; lớp 2 milestone copy-only PR→issue (không block/không warn — giữ gate triage); lớp 3 phán đoán ngoài phạm vi; điểm ép dời sang PR vì `Closes #N` đóng issue như hệ quả merge. Script `post-close-traceability.sh` (hàm thuần `extract_issue_numbers`/`render_comment` test offline) + companion `.test.sh`. Forward-only (backfill đã xong). Loại: block-milestone, warn-PR-time, comment-giàu, gộp-không-ADR, sinh-phán-đoán, `pull_request_target`. Triage: milestone 1.2.0, không priority-high. Chờ duyệt.
