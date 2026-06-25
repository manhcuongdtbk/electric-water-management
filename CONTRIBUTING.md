# Hướng dẫn đóng góp (CONTRIBUTING)

Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` — tài liệu canonical của dự án. Quyết định kèm lý do nằm trong `docs/superpowers/specs/`. Người mới nên đọc `docs/HUONG_DAN_SDLC.md` trước cho dễ vào. Thuật ngữ, từ viết tắt và định nghĩa "canonical": tra [`docs/THUAT_NGU.md`](docs/THUAT_NGU.md).

> Mọi quy ước viết (tuyệt đối không viết tắt), ngôn ngữ (tài liệu/giao diện tiếng Việt; code/commit tiếng Anh) theo `AGENTS.md`.

## 1. Trước khi bắt đầu

- Đọc `AGENTS.md` (quy ước) và tài liệu nguồn trong `docs/` (nghiệp vụ, thiết kế, hành vi, kiểm thử).
- Cài đặt và chạy: xem `README.md` (Docker + git worktree). **Luôn làm việc trong một git worktree riêng + Docker** — cho cả người lẫn AI.

**Checklist onboarding (thành viên mới) — làm theo thứ tự:**

- [ ] Đọc `docs/HUONG_DAN_SDLC.md` — lối vào ~10 phút: vòng đời một thay đổi + bản đồ tra cứu trỏ tới các mục bên dưới.
- [ ] Cài Docker + tạo git worktree riêng, chạy `bin/docker up` (xem `README.md`).
- [ ] Đọc `AGENTS.md` (quy ước) và tài liệu nguồn trong `docs/` liên quan việc bạn làm.
- [ ] Việc đầu tiên: theo "Luồng làm một thay đổi" (mục 4); mọi việc bắt đầu từ một GitHub Issue (mục 9).

## 2. Mô hình nhánh — Git Flow

Theo ADR-003 (xem `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` để biết lý do và sơ đồ đầy đủ).

- `main` — chỉ chứa bản đã phát hành; mỗi commit trên `main` đều có tag version tương ứng.
- `develop` — nhánh tích hợp công việc đang làm.
- `feature/*` — cắt từ `develop`, làm xong merge ngược về `develop`.
- `release/*` — cắt từ `develop` khi đủ nội dung; dùng để ổn định nội dung trước khi vào `main`. **Không** deploy lên Railway và **không** tag `-rc.N` — môi trường Acceptance chạy thẳng `main` (xem ADR-005/008).
- `hotfix/*` — cắt từ `main` khi production lỗi gấp.
- **Merge-back bắt buộc:** sau khi `release/*` hoặc `hotfix/*` hoàn tất, phải merge ngược về `develop` để bản vá không bị mất.
- **Cổng nhánh:** pull request đích `main` chỉ được đến từ `release/*` hoặc `hotfix/*` (branch-source guard sẽ ép ở CI — xem ADR-011).
- **Kiểu merge pull request** (quan trọng cho changelog của release-please):
    - feature/fix → `develop`: dùng **Squash and merge** — mỗi pull request gộp thành **1 commit conventional**, changelog 1 dòng/PR, **không bị trùng dòng**.
    - `release/*`/`hotfix/*` → `main` và merge-back `main` → `develop`: dùng **Create a merge commit** — giữ từng commit để release-please liệt kê đầy đủ trong changelog.
    - *Vì sao squash cho feature:* GitHub **không có** cấu hình nào làm merge commit "không-conventional" (mọi tổ hợp title/message đều đưa tiêu đề pull request vào merge commit). Nếu merge feature bằng merge-commit, release-please đếm **cả** commit thật **lẫn** merge commit → **trùng dòng**. Squash chỉ tạo 1 commit nên tránh được. (Repo đã đặt squash: title = tiêu đề pull request, body để trống.)
    - Đặt tiêu đề pull request của `release/*`/`hotfix/*`/merge-back bằng prefix **không phải loại changelog** (ví dụ `release:`) để merge commit của chúng không thêm dòng thừa vào changelog.
- **Đồng bộ base vào nhánh đang làm** (khi pre-push guard báo nhánh tụt sau base): tích hợp bằng `git merge origin/<base>` hoặc `rebase` rồi push lại. Merge commit **không** cần đúng Conventional Commits — `commitlint.config.mjs` đã ignore mọi commit mở đầu `Merge ` nên không làm đỏ CI.

## 3. Conventional Commits (commit message tiếng Anh)

- Định dạng: `type(scope): subject` — ví dụ `feat(billing): ...`.
- `type` thường dùng: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`.
- Liên hệ SemVer (ADR-004): `feat` → tăng MINOR; `fix` → tăng PATCH; có `BREAKING CHANGE:` trong body hoặc `type!` → tăng MAJOR.
- release-please dựa vào commit message để tự bump version + sinh changelog (ADR-008) → viết commit nghiêm túc, đúng `type`.
- Ví dụ:

```text
feat(billing): add cross-period comparison column
fix(meter): guard against stale lock_version on concurrent update
docs(sdlc): add CONTRIBUTING and canonical AGENTS files
```

- Nếu làm cùng AI, kết commit bằng dòng đồng tác giả theo quy ước repo:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## 4. Luồng làm một thay đổi

Mọi thay đổi bắt đầu từ một **GitHub Issue** (luồng đầy đủ + truy vết: xem mục 9). Sau khi đã có Issue `#N`:

1. Tạo worktree + nhánh `feature/<việc>` từ `develop` (xem `README.md` để biết lệnh worktree + cổng Docker).
2. Code và test: `bin/docker rspec` (test phải cover mọi output của trang — xem `AGENTS.md`).
3. Chạy review AI local **trước khi push**: `/code-review` (ADR-009; dùng Claude sẵn có, không tốn thêm).
4. Mở pull request đích `develop` (với `feature/*`); mô tả ghi `Refs #N` (hoặc `Closes #N` nếu giải quyết trọn). CI xanh + chủ dự án duyệt → merge.
5. Pull request đích `main` chỉ đến từ `release/*` hoặc `hotfix/*`.

> Khi nào gom `develop` thành `release/*`: xem **mục 11** — cổng "release-readiness": mọi Issue `priority-high` của milestone đã merge vào `develop`.

### Việc nối tiếp phụ thuộc (nhánh xếp chồng)

Khi việc B cần kết quả của việc A mà A **chưa merge** (đang chờ CI hoặc chờ duyệt): đừng đợi. Cắt `feature/B` **từ nhánh A** (không phải từ `develop`) rồi làm tiếp ngay — không kẹt chờ CI của A.

- Khi A đã merge vào `develop`, rebase B để bỏ các commit của A ra:

  ```bash
  git fetch origin
  git rebase --onto origin/develop <A> feature/B   # <A> = commit/nhánh A mà B đã cắt từ đó
  ```

- Rồi mở pull request B đích `develop` như thường (mục 4).
- Nếu A bị sửa theo review trước khi merge: rebase B lên nhánh A mới (`git rebase A feature/B`) rồi làm tiếp.

Cùng tinh thần với path filter (ADR-021, mục 8): cái gì tăng tốc được thì để CI lo, cái gì là *quy trình* (chuỗi phụ thuộc) thì xử bằng quy trình — không đổi phút CI lấy wall-clock.

## 5. Pair lập trình / cùng test app đang chạy local — VS Code Dev Tunnels

Theo ADR-010.

- Trong VS Code hoặc Cursor: chạy app local (`bin/docker up`), mở tab **Ports**, chọn **Forward a Port** cho cổng nginx mà `bin/docker` gán cho worktree.
- Đặt visibility **Private** (mặc định) → người trong team đăng nhập GitHub để truy cập. **Không** để Public khi có dữ liệu thật.
- Dự phòng (cần URL ngoài editor hoặc không muốn bắt đăng nhập GitHub): **Cloudflare Tunnel**.
- Người không phải dev (ví dụ khách nghiệm thu): dùng **môi trường Acceptance trên Railway** thay vì tunnel.

## 6. Phát hành

Quy trình đầy đủ và checklist: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.

Tóm tắt: đủ nội dung → `release/*` ← `develop` → merge vào `main` → release-please tạo Release pull request → bạn merge → tag `X.Y.Z` → môi trường **Acceptance** (chạy `main`) cập nhật cho khách nghiệm thu → giao bản tag xuống production Mini PC + fast-forward nhánh `production` (môi trường **Mirror** cập nhật) → **merge-back về `develop`**. (KHÔNG dùng `-rc.N` / không deploy `release/*` lên Railway — ADR-005/008.)

release-please đã được cấu hình (P3): khi `release/*`/`hotfix/*` vào `main`, nó tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`); bạn merge Release pull request → tự tag `vX.Y.Z` + tạo GitHub Release. **Lưu ý:** release-please ghi `CHANGELOG.md`/`version.txt` lên `main`, nên khi merge-back nhớ **đồng bộ `main` → `develop`** để develop có các file đó.

### Ghi chú phát hành tiếng Việt

Sau khi release-please tạo GitHub Release (tiếng Anh, tự động), workflow `release-notes-vi.yml` **tự prepend template tiếng Việt** (heading + 2 phần "(chưa soạn)") vào đầu release body (ADR-066). Không cần API key, không chi phí. Idempotent: skip nếu body đã chứa "Phiên bản".

**Chủ dự án duyệt** nội dung AI đã soạn trước khi công bố (gate — ADR-029). Sửa trực tiếp trên GitHub hoặc `gh release edit`. Nếu cần soạn lại thủ công, format:

```bash
gh release edit vX.Y.Z --notes "$(cat <<'NOTES'
# Phiên bản X.Y.Z (ngày/tháng/năm)

## Tóm tắt cho người dùng
(ngôn ngữ đơn giản, không jargon — cho người dùng cuối)

## Chi tiết cho chủ dự án
(kỹ hơn, có thể nhắc tên trang/tài liệu — cho người quyết định triển khai)

---

(phần CHANGELOG tiếng Anh auto-generated giữ nguyên bên dưới)
NOTES
)"
```

## 7. Giao bản cho khách

- Dùng `bin/prepare-delivery` để tạo bản sạch trước khi ship: script xóa các file dev nội bộ (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.claude/`) và dọn git history. **KHÔNG** ship source code trực tiếp từ repo này.
- Chi tiết deploy production: `docs/HUONG_DAN_DEPLOY.md` và `docs/KIEN_THUC_DOCKER.md`.

## 8. Trạng thái tự động hoá

**Đây là lớp ánh xạ cụ thể của [ADR-029](docs/superpowers/specs/2026-06-07-sdlc-overview-design.md) (vận hành "trợ lý AI lo cơ học — người giữ gate").** Canonical (`AGENTS.md`, ADR-029) viết **trung lập công cụ** — chỉ nói "trợ lý AI"; mục này gắn nguyên tắc đó vào **công cụ hiện đội dùng: Claude Code**. Nếu sau này đổi/thêm tool (Codex, Antigravity…), chỉ cần cập nhật mục này, không đụng canonical. Ánh xạ phần **cơ học** của ADR-029 sang cơ chế Claude Code có sẵn:

- **Theo dõi CI** sau khi mở/cập nhật PR → `PostToolUse` hook tự chạy `gh pr checks` rồi báo pass/fail (xem dưới).
- **Soát lỗi trước khi push** → lệnh `/code-review` (review diff hiện tại theo mức effort; có thể `--comment`/`--fix`).
- **Giữ kỷ luật version tài liệu** (ADR-002) → hook nhắc bump version + changelog khi sửa `docs/`.
- **Chặn push nhánh cũ hơn base** (Git Flow) → `PreToolUse` hook (fail-open).
- **Soạn nháp demo spec cho tính năng hướng-khách** → trợ lý AI soạn hành trình + caption tiếng Việt từ acceptance criteria `NV-...` + UI thật, cùng nhịp với code/test; dùng `rails g demo:spec <feature>` lấy khung rỗng. Người **duyệt video** trước khi tới khách; demo vẫn xanh-mới-merge (ADR-050/051; quy trình tool-neutral ở mục 9 dưới).
- Còn **các gate quyết định** (triage, merge, cắt release, duyệt nội dung gửi khách) **vẫn do người làm tay** — không hook nào tự quyết thay; CI chỉ *hiện trạng thái* (ADR-007), người merge.

**CI tĩnh đã chạy trên mọi pull request (P2):** `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, và **branch-source guard** (chặn pull request đích `main` đến từ nhánh không phải `release/*`/`hotfix/*`). Theo ADR-007, CI chỉ **hiện trạng thái** đỏ/xanh — chưa khoá cứng ở server (repo private không có branch protection miễn phí); kỷ luật một người merge giữ luật.

**CI chạy test đã chạy trên mọi pull request (mảnh "CI spec chi tiết"):** một job `tests` chạy `rspec` (gồm 12 system spec điều khiển headless Chrome), kiểm `db/schema.rb` không lệch, và `rails zeitwerk:check` — trên runner native `ubuntu-latest` + service container Postgres, Chrome qua Selenium Manager. Vẫn theo ADR-007 (chỉ hiện trạng thái). Chi tiết: ADR-012 trong `docs/superpowers/specs/2026-06-07-ci-spec-design.md`.

**CI chỉ chạy job nặng khi pull request đụng code (ADR-021):** một job `changes` (`.github/scripts/detect-code-changes.sh` — native bash, fail-safe) bỏ qua `tests` + `ruby-checks` khi pull request **chỉ sửa tài liệu/meta** (`*.md`, `docs/**`, `LICENSE`…) → pull request docs gần như không tốn phút CI. Bất kỳ file code nào (kể cả workflow) → chạy đủ; bất định (thiếu thông tin, lỗi) cũng **chạy đủ** (fail-safe, không bao giờ bỏ sót test cho thay đổi code). Trigger CI **không** còn `edited` nên sửa tiêu đề/mô tả pull request không chạy lại CI. Chi tiết: ADR-021 trong `docs/superpowers/specs/2026-06-07-ci-spec-design.md`.

**release-please đã cấu hình (P3):** workflow `release-please` chạy trên `main` tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`), merge thì tự tag + tạo GitHub Release. Môi trường **Acceptance** chạy thẳng `main` cho khách nghiệm thu nên **không dùng rc/UAT** (ADR-005/008).

**Claude Code tự giám sát CI (`.claude/settings.json`):** một `PostToolUse` hook nhắc Claude Code — sau khi tạo/cập nhật pull request (`gh pr create`/`edit`/`ready`/`reopen`) — tự theo dõi CI (`gh pr checks`) rồi báo kết quả pass/fail, không phải tự kiểm tay. Cần `jq` + `gh` (release workflow đã dùng `gh`); thiếu `jq` thì hook im lặng (không lỗi, không nhắc). Xem/sửa/tắt qua menu `/hooks`.

**Claude Code chặn push nhánh cũ (`.claude/hooks/check-branch-behind-base.sh`):** một `PreToolUse` hook — trước `git push`, kiểm tra nhánh hiện tại có cũ hơn base không (base theo Git Flow: `release/*`·`hotfix/*` → `main`; còn lại → base của pull request, mặc định `develop`). Nếu cũ hơn → **chặn push** và nhắc tích hợp base trước (merge/rebase, hỏi khi xung đột, re-check hot file như release spec). **Bỏ qua lệnh xóa nhánh** (`--delete`/`-d` hoặc refspec dạng `:branch`) vì xóa nhánh không đẩy nội dung từ nhánh hiện tại. Fail-open: không xác định được base/mạng thì cho push. Cần `jq` + `gh`.

**Claude Code nhắc bump version tài liệu (`.claude/hooks/remind-doc-version-bump.sh`):** một `PostToolUse` hook — khi sửa một file `docs/` có version header, nhắc bump version + thêm entry changelog trong cùng commit (ADR-002). Chỉ nhắc, không chặn; fail-open. Cần `jq`.

**Đã làm thêm (P4):** ba môi trường Railway `development`/`acceptance`/`mirror` (Acceptance chạy thẳng `main`, không dùng `-rc.N` — xem `README.md` + ADR-005); bốn mảnh SDLC trong Backlog của release spec đã xong. Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.

**CI guardrail quản trị tài liệu (ADR-024):** một job `doc-governance` chạy trên **mọi** pull request, kiểm: link nội bộ chết, bản đồ tài liệu (`docs/BAN_DO_TAI_LIEU.md`) phủ đủ và không có đường dẫn ma, và 6 viết tắt + 11 jargon còn định nghĩa trong `docs/THUAT_NGU.md`. Đỏ nếu vi phạm (fail-loud). Không quét prose tìm viết tắt mới (bất khả thi cho tiếng Việt) — việc đó vẫn thuộc review người. Chi tiết: ADR-024 trong `docs/superpowers/specs/2026-06-11-guardrail-quan-tri-tai-lieu-design.md`.

**CI guardrail truy vết chiều test (ADR-030):** script thứ tư của job `doc-governance` (`check-test-dimensions.sh`) đối chiếu bảng `## Truy vết chiều test` của mỗi spec với anchor `CHIEU-<slug>` nhúng trong mô tả `it` của test (`spec/`). Đỏ nếu: một chiều **required** thiếu test; một chiều **DEFERRED** không kèm `#<số>`; anchor `CHIEU-` dùng trong test mà không có trong bảng nào (orphan); hoặc một anchor khai trùng ở hai spec. Biến luật AGENTS "test mọi output + cả 7 vai trò" thành máy-ép cho phần khai-tường-minh. Việc "spec có đủ chiều chưa" vẫn là review người (checklist plan/PR). Chi tiết: ADR-030 trong `docs/superpowers/specs/2026-06-13-truy-vet-chieu-test-design.md`.

**Chiều review "tuân AGENTS" (ADR-031):** review code — người và Claude khi chạy `/code-review` — không chỉ soi đúng/sai chức năng của diff mà còn kiểm tuân thủ quy ước AGENTS. Bốn chiều và cách phủ:

| Chiều | Kiểm gì | Cơ chế phủ |
|---|---|---|
| **i18n** | Chữ người dùng qua `t(...)` + `config/locales/vi.yml`; không hard-code tiếng Việt | Máy-ép: guardrail i18n cho view (ADR-032) bắt literal tiếng Việt **mới** ngoài `t(...)` trong `app/views/**/*.erb`; phần cũ grandfather qua baseline. Chữ không-dấu/ngoài view còn người/AI |
| **Không viết tắt** | Mọi viết tắt mới (code/i18n/giao diện/commit) có trong `docs/THUAT_NGU.md` | Người/AI — ngữ nghĩa, máy không grep được |
| **BigDecimal tiền/điện** | Tiền/điện giữ BigDecimal xuyên suốt; `.to_f`/`Float()` chỉ ở ranh giới hiển thị/Excel; làm tròn `ROUND_HALF_UP` chỉ khi hiển thị | Custom RuboCop cop `Decimal/*` (job `ruby-checks`) bắt ca rõ ràng ở `app/models`,`app/services`; người/AI soi ca lẩn đường vòng |
| **Phủ đủ mọi vai trò** | Test phủ mọi vai trò thực tế (xem `V2_HANH_VI_HE_THONG.md` mục 1) hoặc hoãn tường minh | ADR-030 ép liên kết chiều test ↔ test; người/AI soi đủ vai trò |

Bề mặt ép: (1) cop `Decimal/*` máy-ép phần BigDecimal; (2) hook `UserPromptSubmit` (`.claude/settings.json`) bơm chiều này vào Claude khi gõ `/code-review`; (3) checkbox trong `.github/pull_request_template.md`. Không sửa prompt `/code-review`/review subagent vì chúng là plugin toàn cục, không version-controlled trong repo. Chi tiết + lý do: ADR-031 (`docs/superpowers/specs/2026-06-13-dimension-review-tuan-agents-design.md`).

**CI guardrail i18n cho view (ADR-032):** một job `i18n-view-guardrail` chạy trên **mọi** pull request (`.github/scripts/check-view-i18n.sh`, native bash fail-loud) quét `app/views/**/*.erb` và **đỏ** khi có literal tiếng Việt **mới** — ký tự có dấu, ngoài comment, ngoài `t(...)` — **không** có trong baseline `.github/i18n-view-baseline.txt`. Phần hard-code **đã có** được grandfather qua baseline (không ép migration vì app single-locale). Ngoại lệ hợp lệ / ghi nhận một đợt migrate: regenerate baseline bằng `UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh` (diff baseline hiện trong pull request, người gác merge duyệt). Không bắt chữ người-dùng **không dấu** hoặc **ngoài view** — phần đó còn người/AI (chiều i18n ở bảng trên). Chi tiết + lý do: ADR-032 trong `docs/superpowers/specs/2026-06-13-guardrail-i18n-view-design.md`.

**CI guardrail trạng thái ADR (ADR-033):** script thứ 5 của job `doc-governance` (`check-adr-status.sh`, native bash fail-loud) ép quy ước trạng thái ADR trên `docs/superpowers/specs/*.md`: **R1** — frontmatter **không** mang field `status:` (nguồn duy nhất là dòng inline `**Trạng thái:**` per-ADR); **R2** — dòng `**Trạng thái:** Proposed` phải kèm deferred-marker `chờ quyết #<issue>` (một trích provenance `(Issue #N)` **không** tính là hoãn), nếu không → đỏ. Quy ước: **merge = Accepted** (tác giả ghi `Accepted · <ngày>` ngay trong pull request — merge là hành động duyệt, ADR-007); `Proposed (chờ quyết #<issue>)` chỉ khi cố ý hoãn. Script bỏ code fence + inline-code trước khi soi nên ví dụ prose (bọc backtick) không báo nhầm; không đụng `**Trạng thái khách:**`. Chi tiết + lý do: ADR-033 trong `docs/superpowers/specs/2026-06-13-trang-thai-adr-lifecycle-design.md`.

**Tự động khép dấu vết khi đóng issue (ADR-035):** một workflow `close-traceability.yml` chạy **hậu-merge** trên `pull_request: closed` (gate `merged == true`). Với mỗi closing-keyword `Closes/Fixes/Resolves #N` trong body pull request, script `.github/scripts/post-close-traceability.sh` (a) post một **comment kết cơ học** vào issue — PR#/tiêu đề, merge SHA, nhánh đích, thời điểm merge, dòng milestone — idempotent qua marker ẩn `<!-- auto-close-traceability:pr-N -->`; và (b) **copy milestone PR→issue** khi PR có milestone còn issue chưa (copy-only: KHÔNG chặn, KHÔNG ghi đè, KHÔNG cảnh báo — giữ gate triage ADR-019/020). Phần **phán đoán** (sai khác plan, caveat, chiều test đã phủ) máy KHÔNG sinh — người/AI bổ sung khi có nuance. Điểm ép ở pull request (không ở issue) vì `Closes #N` đóng issue như hệ quả merge. Chi tiết + lý do: ADR-035 trong `docs/superpowers/specs/2026-06-13-close-traceability-automation-design.md`.

**CI guardrail header changelog (#339):** script thứ 6 của job `doc-governance` (`check-changelog-header.sh`, native bash fail-loud) ép tài liệu spec dùng **một** header lịch sử duy nhất `## Lịch sử thay đổi` (khớp `AGENTS.md` mục version/changelog), **không** dùng biến thể `## Changelog` → đỏ nếu gặp heading `## Changelog`. Bỏ qua khối code fence (ví dụ minh hoạ không tính) và prose nhắc tới (bọc backtick không phải heading). Phạm vi: `docs/superpowers/specs/*.md` (plans là bản ghi lịch sử, ngoài phạm vi).

**CI guardrail đồng bộ tài liệu-code (ADR-062):** 4 script trong job `doc-governance` so sánh nội dung tài liệu với nguồn sự thật trong code, **đỏ** khi lệch: (1) `check-role-count.sh` — đếm enum `user_role` trong `db/schema.rb` + đếm vai trò thực tế trong `spec/support/role_access_matrix.rb` → so với số "N vai trò" trong 4 tài liệu canonical; (2) `check-schema-coverage.sh` — mọi bảng trong `db/schema.rb` phải có heading `####` trong `V2_THIET_KE_HE_THONG.md`; (3) `check-cleanup-callbacks.sh` — model có `before_discard`/`after_discard` phải có trong bảng cleanup của `V2_THIET_KE_HE_THONG.md` (Block/Group skip vì callback nullify, không hard-delete, tài liệu ở mục "Xóa dữ liệu"); (4) `check-discarded-at-indexes.sh` — bảng có cột `discarded_at` phải có entry `(discarded_at) | Regular` trong bảng index của `V2_THIET_KE_HE_THONG.md`. Phủ 8/13 pattern drift phổ biến nhất từ cross-check audit (#456/#457/#459/#462). Drift ngữ nghĩa (spec intent ≠ code) vẫn cần người/AI — convention "Simplified marker" (ADR-063) bắt tại nguồn, periodic audit (ADR-064) là lưới an toàn cuối. Chi tiết + lý do: ADR-062..064 trong `docs/superpowers/specs/2026-06-25-doc-code-sync-design.md`.

**CI guardrail truy vết yêu cầu NV (ADR-065):** script trong job `doc-governance` (`check-nv-traceability.sh`, native bash fail-loud) đối chiếu anchor `NV-...` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` với tag `NV-...` trong mô tả `it` của test (`spec/`) và metadata `demo_nv` của demo spec. **Đỏ** nếu: anchor required thiếu test (R1); dòng DEFERRED trong `.github/nv-test-deferred.txt` thiếu `#<số>` (R2); tag NV trong test không khớp anchor nào (orphan, R3); dòng DEFERRED tham chiếu anchor không tồn tại (R4). Song song pattern CHIEU (ADR-030). Chi tiết + lý do: ADR-065 trong `docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md`.

**CI guardrail chống trùng số ADR (ADR-046):** script thứ 7 của job `doc-governance` (`check-adr-numbering.sh`, native bash fail-loud) đối chiếu mọi dòng định nghĩa ADR trong `docs/superpowers/specs/*.md` — heading `## ADR-NNN` **hoặc** `### ADR-NNN` (bắt cả hai cấp; chỉ `###` sẽ bỏ sót) — và **đỏ** nếu một số `ADR-NNN` xuất hiện ở >1 heading (cùng file hoặc khác file). Bỏ code fence nên ví dụ minh hoạ không tính. Bắt cả trùng đang tồn tại lẫn va chạm giữa hai nhánh song song khi nhánh sau đồng bộ `develop` (single-merger renumber nhánh gộp sau — ADR-007). Việc "đặt đúng số kế tiếp" vẫn cần kiểm nhánh/PR đang mở thủ công (số chưa merge vô hình với `develop`). Chi tiết + lý do: ADR-046 trong `docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md`.

## 9. Quản lý thay đổi & truy vết

Theo ADR-013..015 (chi tiết + lý do: `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md`). Mục tiêu: yêu cầu khách **không rơi** và truy được **yêu cầu → thiết kế → test → release**.

### Luồng một thay đổi (6 bước)

1. **Tiếp nhận** — mở **GitHub Issue** bằng template *Yêu cầu thay đổi* (`.github/ISSUE_TEMPLATE/change-request.md`). Yêu cầu đến từ kênh ngoài (lời nói, chat) cũng phải có Issue trước khi vào `feature/*` — đội mở thay khách nếu cần. Số `#N` là mã định danh thay đổi.
2. **Phân loại** — gắn 1 nhãn loại (`change-request` / `enhancement` / `bug`); chốt mức SemVer (`feat`/`fix`/breaking); xác định có đụng nghiệp vụ không. Cần thiết kế → gắn `needs-design`. **Khách có thấy thay đổi này không?** Nếu có → gắn `customer-facing` **ngay tại đây** (đừng đợi PR): nhãn này kéo theo demo spec là **Definition of Done** của cả thiết kế lẫn hiện thực (ADR-052). Gán **milestone = version đích** khi đã biết.
3. **Thiết kế** (nếu cần) — brainstorm → spec trong `docs/superpowers/specs/`; nếu đụng nghiệp vụ, cập nhật `docs/V2_XAC_NHAN_NGHIEP_VU.md` + gắn anchor (xem dưới). Cần khách xác nhận trước khi build → xem **Cổng xác nhận khách trước build** dưới. Gỡ `needs-design`.
4. **Hiện thực + test** — `feature/*`, pull request `Refs #N`, test cover yêu cầu (mục 4). Tính năng **hướng-khách** soạn thêm **demo spec** cùng nhịp (xem *Demo spec cho tính năng hướng-khách* dưới).
5. **Release** — gom vào `release/*` → merge `main` → release-please tag `X.Y.Z`; khách nghiệm thu trên môi trường **Acceptance** (chạy `main`, không dùng `-rc.N` — ADR-005/008) (mục 6).
6. **Đóng** — `Closes #N` khi merge; CHANGELOG tự liệt kê `(#N)`.

**Trạng thái không gắn nhãn tay** — suy ra từ artifact: Issue mở = đang mở; có pull request liên kết = đang làm; merged = xong; có trong CHANGELOG/tag = đã release.

**Khách thấy trạng thái ở mức release** (môi trường Acceptance + release notes tiếng Việt). Khách không truy cập GitHub → đội trả lời "đang ở đâu" từ Issue/milestone list rồi chuyển tiếp.

### Demo spec cho tính năng hướng-khách (ADR-050/051)

Khi làm một tính năng **hướng-khách** (PR gắn nhãn `customer-facing`), soạn **demo spec** trong `spec/demo/` **cùng nhịp với code/test** — coi như một phần của việc làm feature, giống viết test.

**Chốt từ khâu thiết kế (Definition of Done — ADR-052).** Demo spec là **deliverable của thiết kế**, không phải việc-làm-sau. Spec thiết kế của tính năng hướng-khách:

- đặt frontmatter `customer_facing: true`, và
- kết bằng mục **`## Truy vết demo`** trỏ tới một `spec/demo/<x>_demo_spec.rb` (hoặc `DEFERRED #<issue>` nếu hoãn có gate).

Guardrail `check-demo-deliverable.sh` (job `doc-governance`) ép luật này ở **mức spec** — sớm hơn guardrail bắt-buộc-tồn-tại ở PR-time (ADR-040). Ngoài ra, PR đụng path khách-thấy-được (`app/views/**`, `app/javascript/controllers/**`) mà quên nhãn + thiếu demo sẽ nhận **cảnh báo advisory** (không chặn) từ `check-demo-spec.sh` (ADR-052 Lớp C). Ba lớp này cùng khép đường "tính năng khách-thấy-được tới PR mà thiếu demo".

Cách soạn (vận hành AI-assisted, ADR-029 — viết trung lập công cụ; ánh xạ Claude Code ở mục 8):

1. **Lấy khung:** chạy `rails g demo:spec <feature>` → đẻ `spec/demo/<feature>_demo_spec.rb` rỗng nhưng chạy được (boilerplate DSL `DemoRecorder`, `include_context "demo seeded world"`, caption TODO, placeholder `demo_nv: %w[NV-TODO]`). Generator **không** đọc acceptance criteria — không sinh mù (ADR-051).
2. **Soạn nháp:** trợ lý AI điền hành trình + **caption tiếng Việt** suy từ acceptance criteria (`NV-...` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md`) + UI thật; thay `NV-TODO` bằng anchor thật để giữ truy vết xuôi.
3. **Người giữ gate:** demo là spec **xanh-mới-merge** (máy bắt selector/bước sai → anti-drift); **người duyệt video** (chất lượng caption/nghiệp vụ) trước khi tới khách. **Không** có đường CI tự-soạn-rồi-gửi (ADR-050).
4. **Guardrail (ADR-040):** PR `customer-facing` mà thiếu file `spec/demo/**` → CI đỏ. Guardrail ép *sự tồn tại*; các bước trên lo *nội dung*.

> Chạy/xem demo cục bộ: `bin/docker demo spec/demo/<x>_demo_spec.rb` (bỏ tham số để chạy cả `spec/demo`). Lệnh tự set `DEMO=1` — demo spec bị loại khỏi `bin/docker rspec` thường, và `bin/docker bash -c "..."` KHÔNG nhận command nên đừng dùng để chạy demo.

> Hạ tầng + lý do đầy đủ: ADR-036..041 (`docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md`); thói quen soạn + scaffold: ADR-050/051 (`docs/superpowers/specs/2026-06-14-ai-soan-demo-scaffold-design.md`).

### Chuẩn "demo tốt" — chất lượng, không chỉ tồn tại (ADR-059)

Guardrail + CI ép demo **tồn tại** và **chạy**; chúng **không** ép demo **hay** — "hay" là phán đoán con người, không lint được. Demo mẫu của dự án: **`spec/demo/cot_khac_he_so_don_vi_demo_spec.rb`** (TN1). Soi nó khi viết demo mới. Chuẩn ở repo (không ở đầu người), ba tầng chắc dần:

**Tầng 1 — Bộ công cụ (neo kỹ thuật vào `DemoRecorder`, đừng tự chế tại chỗ).** Primitive tái dùng (`spec/support/demo_recorder.rb`):

- `sign_in_as(user, role_label:, caption:)` — đăng nhập **lập trình** qua Warden (server-side), **không dựng trang đăng nhập**. Demo **không được** diễn trang `/users/sign_in` (chậm, không kể gì cho khách); chỉ một caption nêu vai trò. Dùng cho cả lúc đổi vai (vd quản trị viên → chỉ huy) thay vì đăng xuất + đăng nhập lại.
- `visit(path, caption:)` — mở thẳng path (kèm query) vào đúng màn, không lái qua filter.
- `click(locator, caption:, confirm:)` — `confirm: true` chấp nhận hộp xác nhận Turbo (`data-turbo-confirm`); thiếu cờ này form không submit (driver Playwright mặc định dismiss dialog — bài học #363).
- `fill(field, with:, caption:)` · `select(option, from:, caption:)` — nhập/chọn có trỏ + nhịp đọc được.
- `highlight(selector, caption:)` — cuộn một ô/kết quả vào khung + vẽ viền, để thứ caption khẳng định **thấy được trên màn**.
- `narrate(caption)` — caption không thao tác, kể bối cảnh/nhân-quả.
- **Quy ước DOM hook `data-*-cp-id`** trên view (vd `data-other-deduction-cp-id`, `data-total-personnel-cp-id`) — để `highlight` nhắm đúng ô của đúng đầu mối thay vì dò text mong manh.

> Cần kỹ thuật demo mới → **thêm vào `DemoRecorder`/hook DOM**, đừng tự chế trong một spec. Demo sau thừa kế miễn phí.

**Tầng 2 — Khởi đầu đúng-hình.** `rails g demo:spec` sinh khung kèm sẵn pattern tốt (chỗ trống `highlight` để cho-thấy-kết-quả, narration bám-chuyện, ghi chú "đừng diễn thứ browser không dựng — vd Excel") + pointer TN1. Đừng xoá các nhắc đó; thay bằng hành trình thật.

**Tầng 3 — Checklist 6 tiêu chí + tự-soi-như-khách (gate người).** Trước khi xin merge, **xem lại bản quay như một khách chưa biết gì**, đối chiếu 6 tiêu chí, và **báo đã soi gì** ở PR:

1. **Cho thấy, đừng nói** — mọi điều caption khẳng định phải *thấy được* trên màn (dùng `highlight`).
2. **Kể đúng chuyện khách** — khớp ví dụ/thế giới thật của khách, không chỉ số đúng.
3. **Diễn kết quả + cái đau được xoá**, không diễn thao tác.
4. **Trung thực với medium** — không diễn thứ browser không dựng (vd `.xlsx`); cái đó để test/file thật lo.
5. **Đủ cung đường khách quan tâm**, không nhồi mọi ngóc ngách/chiều test.
6. **Ổn định** — không "xanh nhờ may" (dùng `confirm:`/`unpoint`-rescue; không đua điều hướng).

> Chuẩn + lý do đầy đủ: ADR-059 (`docs/superpowers/specs/2026-06-14-demo-dod-design.md`, mục "Chuẩn demo tốt").

### Thứ tự trang cho demo vai trò

Khi demo video cho một vai trò (đặc biệt vai trò mới), duyệt trang theo thứ tự nghiệp vụ — lớn → nhỏ, thiết lập → nhập liệu → kết quả:

1. **Cấu trúc** (lớn → nhỏ): khu vực → đơn vị → khối → nhóm → đầu mối
2. **Thiết lập**: đơn giá điện → nhóm cấp bậc → phân bổ bơm nước
3. **Nhập liệu** (tổng quan → chuyên sâu): nhập số điện lực → chỉ số đầu mối → chỉ số bơm nước → cấu hình đơn vị
4. **Kết quả** (tổng quan → chi tiết → lịch sử): tổng quan → bảng tính tiền → tra cứu lịch sử
5. **Hệ thống**: nhật ký hoạt động
6. **Bị chặn**: tài khoản, sao lưu dữ liệu (nếu vai trò không truy cập)

Lý do thứ tự: không biết cấu trúc → không hiểu thiết lập; không biết thiết lập → không hiểu nhập liệu; không biết nhập liệu → không hiểu kết quả. Arc demo: mở đầu bằng cái đau (vai trò hiện tại thiếu gì) → đăng nhập vai trò mới → duyệt 6 nhóm trên → kết.

### Cổng xác nhận khách trước build (ADR-028)

Khi cần khách **xác nhận yêu cầu/phương án trước khi build** (thường qua nhiều lượt), làm trong bước 3:

1. Đã có Issue `#N` (bước 1). Tài liệu xác nhận mở đầu bằng `#N`.
2. Soạn **tài liệu xác nhận** ở `docs/xac-nhan-khach/` (tạo thư mục khi lần đầu cần) — KHÔNG để ở `docs/` gốc (tránh trông như nguồn nghiệp vụ).
3. Mỗi vòng khách phản hồi: cập nhật tài liệu, **bump version + 1 dòng changelog** (ADR-002), ghi vết comment vào Issue (khách duyệt/điều chỉnh gì, ngày).
4. Khai trong `docs/BAN_DO_TAI_LIEU.md` **per-file**: **current-state** khi đang chốt → **lịch sử** khi đã chốt + đã fold.
5. **Chỉ khi khách chốt** mới fold yêu cầu vào `docs/V2_XAC_NHAN_NGHIEP_VU.md` (canonical) + anchor `NV-...`; từ đó mới code theo. Trước đó tài liệu xác nhận chỉ là "đang đề xuất".
6. Trợ lý AI soạn / đánh version / ghi vết / fold; bạn duyệt nội dung gửi khách + duyệt fold (vận hành AI-assisted, ADR-029).

> Ca mẫu: đợt 1 xác nhận nghiệp vụ bổ sung (#264/#319) — xem `docs/V2_XAC_NHAN_NGHIEP_VU.md` mục 29 "Truy vết xác nhận nghiệp vụ".

### Mã định danh yêu cầu (anchor `NV-...`)

- Khi **lần đầu** cần link tới một yêu cầu trong `docs/V2_XAC_NHAN_NGHIEP_VU.md`, thêm `<a id="NV-<slug-chủ-đề>"></a>` ngay trước heading mục/tiểu mục đó. Slug **không dấu, theo chủ đề** (ví dụ `NV-phan-bo-bom-nuoc`), **không buộc vào số mục** (để bền khi tài liệu chèn/đánh số lại).
- Thêm lười (lazy): chỉ gắn anchor cho yêu cầu thực sự được truy vết. Sửa `docs/V2_XAC_NHAN_NGHIEP_VU.md` thì **bump version + changelog** của nó (ADR-002).

### Liên kết truy vết

- Mỗi spec thiết kế kết bằng mục `## Truy vết` trỏ **lên** (yêu cầu `NV-...` + Issue `#N`) và **liệt kê test** cover yêu cầu.
- **Test ↔ yêu cầu:** link ở phía spec/pull request, **không** gắn mã vào code test. Yêu cầu cũ (chưa có design spec) trỏ `docs/V2_KICH_BAN_TEST.md` / `docs/V2_CHIEU_TEST.md`.
- **Chiều test ↔ test (`CHIEU-<slug>`):** khác với `NV-` ở trên — chiều test **có** gắn mã vào test. Spec tính năng kết phần chiều test bằng bảng `## Truy vết chiều test` (`| Mã `CHIEU-<slug>` | mô tả | có test \| DEFERRED #issue |`); test mang anchor ở mô tả `it "CHIEU-<slug>: ..."`. CI (`check-test-dimensions.sh`, ADR-030) đối chiếu hai bên. Hoãn một chiều → ghi `DEFERRED #<issue-gate>`, không bỏ im. Map mỗi chiều test của spec + 2 luật AGENTS (mọi-output, 6-vai-trò) → một hàng khi viết plan.
- **Truy vết hai chiều bằng grep:** xuôi `grep -rn "NV-<slug>" docs/`; ngược từ `(#N)` trong CHANGELOG/commit → Issue → mô tả gốc.

> Tiếp nhận/ưu tiên backlog xem **mục 11** (Backlog #4). Lỗi/sự cố production xem mục 10.

## 10. Vận hành & xử lý sự cố

Theo ADR-016..018 (chi tiết + lý do: `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md`). Đặt *quy trình* lên trên tính năng đã có (sao lưu 3 lớp, nhật ký mục 20, `/up` + `/version`, Docker); how-to thao tác xem `docs/HUONG_DAN_DEPLOY.md` + `docs/KIEN_THUC_DOCKER.md` mục 10.

### Giám sát Mini PC offline (ADR-016)

Không có nhịp định kỳ. Giám sát = **review khi giao phiên bản** + lưới auto-backup nền + tra nhật ký mục 20 theo yêu cầu. Checklist khi giao bản (tại hộp):

- [ ] 3 container `Up` (`docker compose ps`).
- [ ] `/up` xanh; `/version` đúng bản vừa giao.
- [ ] Đĩa còn chỗ (`df -h`, `docker system df`).
- [ ] Cron auto-backup (ổ phụ) có file/log mới.

### Sao lưu & khôi phục (ADR-017)

- **Lớp 3 (auto, ổ phụ, 7 bản) = nguồn cậy chính, bắt buộc.** Lớp 1 (giao diện, 3 bản) = snapshot trước thao tác nguy hiểm. How-to: deploy guide mục Sao lưu.
- **Diễn tập khôi phục mỗi lần giao bản, phía dev/nghiệm thu:** chạy `backups:restore` với một backup sinh ở đó để chứng minh cơ chế của đúng version chạy được. Không diễn tập trên prod; không mang file backup prod ra ngoài.
- **Trên prod:** chỉ khôi phục thật khi sự cố; **luôn tạo backup Lớp 1 trước khi restore**.

### Tiếp nhận lỗi/sự cố (ADR-018)

Lỗi/sự cố là một "thay đổi" — dùng luồng 6 bước mục 9, chỉ khác template + đường vá:

1. **Tiếp nhận** — mở Issue bằng template *Báo lỗi / sự cố* (`.github/ISSUE_TEMPLATE/bug-report.md`); khách báo qua kênh ngoài thì đội mở thay. Nhãn `bug`.
2. **Phân loại mức độ → đường vá:**
   - **Nghiêm trọng** (prod không dùng được / sai số tiền / mất hoặc nguy cơ mất dữ liệu) → gắn thêm nhãn `severity-critical`; vá theo `hotfix/*` ← `main` (mục 2); cân nhắc **rollback tag trước** trên Mini PC làm bước chữa cháy tức thì.
   - **Thường** (vẫn dùng được) → luồng `feature/*` → `develop` → `release/*`, gồn vào bản sau.
3. **Vá + test** — pull request `Refs #N`, test cover lỗi.
4. **Phát hành + giao** — tag (release-please); giao Mini PC + fast-forward `production`.
5. **Đóng + báo khách** — `Closes #N`; báo khách kèm release notes tiếng Việt.

> Nhãn `severity-critical` tạo một lần khi lần đầu cần (production hiện đang hoãn): `gh label create severity-critical --color B60205 --description "Lỗi nghiêm trọng - đường hotfix"`.

## 11. Ưu tiên công việc (backlog)

Theo ADR-019..020 (chi tiết + lý do: `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md`). Mục tiêu: từ danh sách Issue đang mở biết **làm cái nào trước** và **khi nào release đủ nội dung để cắt** — không sổ thứ hai, không nghi thức.

### Một backlog

Backlog = **mọi GitHub Issue đang mở** (yêu cầu/thay đổi mục 9, lỗi/sự cố mục 10 — chung một danh sách). Không có file backlog riêng.

### Hai trục ưu tiên

- **`milestone` = version đích** (đã có ở mục 9): Issue dự kiến vào bản phát hành nào.
- **Nhãn `priority-high`**: đánh dấu Issue **phải có** cho milestone của nó. Issue không gắn = nên-có / thường.

### Thứ tự kéo việc (pull)

1. **`severity-critical`** (mục 10) — sự cố nghiêm trọng, vá gấp `hotfix/*`, **ngoài hàng đợi**; **không** kèm `priority-high`.
2. **`priority-high`** theo milestone.
3. Phần còn lại.

### Nhịp

Ad-hoc, **gộp vào bước Phân loại** (mục 9, bước 2): khi triage một Issue, chủ dự án gán milestone + (nếu phải-có) `priority-high`. **Không** họp grooming định kỳ; xem lại cơ hội khi cắt release. Chủ dự án là người quyết ưu tiên.

### Cổng "release đủ nội dung để cắt"

Một milestone **sẵn sàng cắt `release/*`** khi **mọi** Issue `priority-high` của nó đã xong (merged vào `develop`). Việc **không cờ** chưa xong → **reslot** milestone sang bản sau (không chặn release). Kiểm bằng:

```bash
gh issue list --label priority-high --milestone <version> --state open
# rỗng → milestone đủ nội dung phải-có → cắt release/<version>
```

> Nhãn `priority-high` tạo một lần khi lần đầu cần (đội bắt đầu dùng milestone để ưu tiên): `gh label create priority-high --color FBCA04 --description "Phải có cho milestone (ưu tiên kéo việc)"`.

## Tài liệu liên quan

- `AGENTS.md` — quy ước canonical (code + quy trình).
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-001 (mô hình phát triển), ADR-002 (chiến lược tài liệu/tri thức).
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — ADR-003..011 (quy trình phát hành).
- `README.md` — cài đặt, lệnh thường dùng, môi trường.
