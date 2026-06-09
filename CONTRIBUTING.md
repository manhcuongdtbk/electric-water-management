# Hướng dẫn đóng góp (CONTRIBUTING)

Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` (nguồn canonical). Quyết định kèm lý do nằm trong `docs/superpowers/specs/`.

> Mọi quy ước viết (tuyệt đối không viết tắt), ngôn ngữ (tài liệu/giao diện tiếng Việt; code/commit tiếng Anh) theo `AGENTS.md`.

## 1. Trước khi bắt đầu

- Đọc `AGENTS.md` (quy ước) và tài liệu nguồn trong `docs/` (nghiệp vụ, thiết kế, hành vi, kiểm thử).
- Cài đặt và chạy: xem `README.md` (Docker + git worktree). **Luôn làm việc trong một git worktree riêng + Docker** — cho cả người lẫn AI.

## 2. Mô hình nhánh — Git Flow

Theo ADR-003 (xem `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` để biết lý do và sơ đồ đầy đủ).

- `main` — chỉ chứa bản đã phát hành; mỗi commit trên `main` đều có tag version tương ứng.
- `develop` — nhánh tích hợp công việc đang làm.
- `feature/*` — cắt từ `develop`, làm xong merge ngược về `develop`.
- `release/*` — cắt từ `develop` khi đủ nội dung; deploy môi trường Nghiệm thu; gắn tag release candidate `X.Y.Z-rc.N`.
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

## 5. Pair lập trình / cùng test app đang chạy local — VS Code Dev Tunnels

Theo ADR-010.

- Trong VS Code hoặc Cursor: chạy app local (`bin/docker up`), mở tab **Ports**, chọn **Forward a Port** cho cổng nginx mà `bin/docker` gán cho worktree.
- Đặt visibility **Private** (mặc định) → người trong team đăng nhập GitHub để truy cập. **Không** để Public khi có dữ liệu thật.
- Dự phòng (cần URL ngoài editor hoặc không muốn bắt đăng nhập GitHub): **Cloudflare Tunnel**.
- Người không phải dev (ví dụ khách nghiệm thu): dùng **môi trường Nghiệm thu trên Railway** thay vì tunnel.

## 6. Phát hành

Quy trình đầy đủ và checklist: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.

Tóm tắt: đủ nội dung → `release/*` → deploy Nghiệm thu (`-rc.N`) → khách nghiệm thu → release-please tạo Release pull request → merge `main` + tag `X.Y.Z` → giao bản xuống production Mini PC + cập nhật môi trường Mốc → **merge-back về `develop`**.

release-please đã được cấu hình (P3): khi `release/*`/`hotfix/*` vào `main`, nó tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`); bạn merge Release pull request → tự tag `vX.Y.Z` + tạo GitHub Release. **Lưu ý:** release-please ghi `CHANGELOG.md`/`version.txt` lên `main`, nên khi merge-back nhớ **đồng bộ `main` → `develop`** để develop có các file đó. Ghi chú phát hành cho khách: biên tập tiếng Việt trên GitHub Release trước khi công bố.

## 7. Giao bản cho khách

- Dùng `bin/prepare-delivery` để tạo bản sạch trước khi ship: script xóa các file dev nội bộ (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.claude/`) và dọn git history. **KHÔNG** ship source code trực tiếp từ repo này.
- Chi tiết deploy production: `docs/HUONG_DAN_DEPLOY.md` và `docs/KIEN_THUC_DOCKER.md`.

## 8. Trạng thái tự động hoá

**CI tĩnh đã chạy trên mọi pull request (P2):** `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, và **branch-source guard** (chặn pull request đích `main` đến từ nhánh không phải `release/*`/`hotfix/*`). Theo ADR-007, CI chỉ **hiện trạng thái** đỏ/xanh — chưa khoá cứng ở server (repo private không có branch protection miễn phí); kỷ luật một người merge giữ luật.

**CI chạy test đã chạy trên mọi pull request (mảnh "CI spec chi tiết"):** một job `tests` chạy `rspec` (gồm 12 system spec điều khiển headless Chrome), kiểm `db/schema.rb` không lệch, và `rails zeitwerk:check` — trên runner native `ubuntu-latest` + service container Postgres, Chrome qua Selenium Manager. Vẫn theo ADR-007 (chỉ hiện trạng thái). Chi tiết: ADR-012 trong `docs/superpowers/specs/2026-06-07-ci-spec-design.md`.

**release-please đã cấu hình (P3):** workflow `release-please` chạy trên `main` tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`), merge thì tự tag + tạo GitHub Release. Phần **rc/UAT để dành P4**.

**Claude Code tự giám sát CI (`.claude/settings.json`):** một `PostToolUse` hook nhắc Claude Code — sau khi tạo/cập nhật pull request (`gh pr create`/`edit`/`ready`/`reopen`) — tự theo dõi CI (`gh pr checks`) rồi báo kết quả pass/fail, không phải tự kiểm tay. Cần `jq` + `gh` (release workflow đã dùng `gh`); thiếu `jq` thì hook im lặng (không lỗi, không nhắc). Xem/sửa/tắt qua menu `/hooks`.

**Claude Code chặn push nhánh cũ (`.claude/hooks/check-branch-behind-base.sh`):** một `PreToolUse` hook — trước `git push`, kiểm tra nhánh hiện tại có cũ hơn base không (base theo Git Flow: `release/*`·`hotfix/*` → `main`; còn lại → base của pull request, mặc định `develop`). Nếu cũ hơn → **chặn push** và nhắc tích hợp base trước (merge/rebase, hỏi khi xung đột, re-check hot file như release spec). Fail-open: không xác định được base/mạng thì cho push. Cần `jq` + `gh`.

**Claude Code nhắc bump version tài liệu (`.claude/hooks/remind-doc-version-bump.sh`):** một `PostToolUse` hook — khi sửa một file `docs/` có version header, nhắc bump version + thêm entry changelog trong cùng commit (ADR-002). Chỉ nhắc, không chặn; fail-open. Cần `jq`.

**Còn ở các giai đoạn sau:** môi trường Railway Nghiệm thu + Mốc + bản rc (P4); các mảnh SDLC còn lại trong Backlog của release spec. Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.

## 9. Quản lý thay đổi & truy vết

Theo ADR-013..015 (chi tiết + lý do: `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md`). Mục tiêu: yêu cầu khách **không rơi** và truy được **yêu cầu → thiết kế → test → release**.

### Luồng một thay đổi (6 bước)

1. **Tiếp nhận** — mở **GitHub Issue** bằng template *Yêu cầu thay đổi* (`.github/ISSUE_TEMPLATE/change-request.md`). Yêu cầu đến từ kênh ngoài (lời nói, chat) cũng phải có Issue trước khi vào `feature/*` — đội mở thay khách nếu cần. Số `#N` là mã định danh thay đổi.
2. **Phân loại** — gắn 1 nhãn loại (`change-request` / `enhancement` / `bug`); chốt mức SemVer (`feat`/`fix`/breaking); xác định có đụng nghiệp vụ không. Cần thiết kế → gắn `needs-design`. Gán **milestone = version đích** khi đã biết.
3. **Thiết kế** (nếu cần) — brainstorm → spec trong `docs/superpowers/specs/`; nếu đụng nghiệp vụ, cập nhật `docs/V2_XAC_NHAN_NGHIEP_VU.md` + gắn anchor (xem dưới). Gỡ `needs-design`.
4. **Hiện thực + test** — `feature/*`, pull request `Refs #N`, test cover yêu cầu (mục 4).
5. **Release** — gom vào `release/*` → bản ứng viên (release candidate) → khách nghiệm thu → release-please tag `X.Y.Z` (mục 6).
6. **Đóng** — `Closes #N` khi merge; CHANGELOG tự liệt kê `(#N)`.

**Trạng thái không gắn nhãn tay** — suy ra từ artifact: Issue mở = đang mở; có pull request liên kết = đang làm; merged = xong; có trong CHANGELOG/tag = đã release.

**Khách thấy trạng thái ở mức release** (môi trường Nghiệm thu + release notes tiếng Việt). Khách không truy cập GitHub → đội trả lời "đang ở đâu" từ Issue/milestone list rồi chuyển tiếp.

### Mã định danh yêu cầu (anchor `NV-...`)

- Khi **lần đầu** cần link tới một yêu cầu trong `docs/V2_XAC_NHAN_NGHIEP_VU.md`, thêm `<a id="NV-<slug-chủ-đề>"></a>` ngay trước heading mục/tiểu mục đó. Slug **không dấu, theo chủ đề** (ví dụ `NV-phan-bo-bom-nuoc`), **không buộc vào số mục** (để bền khi tài liệu chèn/đánh số lại).
- Thêm lười (lazy): chỉ gắn anchor cho yêu cầu thực sự được truy vết. Sửa `docs/V2_XAC_NHAN_NGHIEP_VU.md` thì **bump version + changelog** của nó (ADR-002).

### Liên kết truy vết

- Mỗi spec thiết kế kết bằng mục `## Truy vết` trỏ **lên** (yêu cầu `NV-...` + Issue `#N`) và **liệt kê test** cover yêu cầu.
- **Test ↔ yêu cầu:** link ở phía spec/pull request, **không** gắn mã vào code test. Yêu cầu cũ (chưa có design spec) trỏ `docs/V2_KICH_BAN_TEST.md` / `docs/V2_CHIEU_TEST.md`.
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
