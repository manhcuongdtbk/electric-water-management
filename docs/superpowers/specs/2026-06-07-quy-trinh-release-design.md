---
title: Quy trình phát hành (release process) — Mảnh 1 của SDLC
version: 0.9.0
status: draft (chờ duyệt)
date: 2026-06-07
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Quy trình phát hành (release process)

Mảnh đầu tiên của việc chuẩn hoá SDLC. Tuân theo [SDLC Overview](2026-06-07-sdlc-overview-design.md) (ADR-001 mô hình, ADR-002 tài liệu/tri thức).

> **Cách đọc:** quyết định viết theo **ADR**: Bối cảnh → Quyết định → Lý do → Tradeoff → Phương án đã loại → Điều kiện xem lại → Trạng thái.

## Goals

- Đưa code từ máy dev tới khách **lặp lại được, có version rõ ràng, ép tuân thủ được**.
- **Chi phí thấp nhất**; **không phụ thuộc công cụ bị bỏ rơi**; tự động hoá tối đa.
- Tồn tại đồng thời nhiều version để khách **đối chiếu** (production-mốc vs ứng viên).

## Non-Goals (cố ý KHÔNG làm ở mảnh này)

- Quy trình deploy production offline (đã có người lo) — chỉ chạm tới ở mức "nhận bản đã tag".
- Quy trình tiếp nhận yêu cầu, quản lý thay đổi/truy vết, vận hành/giám sát — là **mảnh SDLC khác** (xem [Backlog](#backlog)).
- Đồng bộ dữ liệu production lên Railway (không cần & không an toàn).

## Glossary (khoá nghĩa — không viết tắt)

| Thuật ngữ | Nghĩa |
|---|---|
| **Release candidate (rc)** | Bản ứng viên chờ khách nghiệm thu; tag `X.Y.Z-rc.N` |
| **Merge-back** | Sau khi `release/*`/`hotfix/*` xong, merge ngược về `develop` để fix không bị mất |
| **Môi trường Nghiệm thu** | App trên Railway chạy `release/*` cho khách thử |
| **Môi trường Mốc** | App trên Railway chạy đúng version đang ở production, để đối chiếu |
| **Production** | Bản chạy thật trên Mini PC mạng LAN offline tại chỗ khách |
| **Promotion** | Đẩy một version từ tầng dưới (nghiệm thu) lên tầng trên (production) |

## Sơ đồ luồng nhánh ↔ môi trường

```mermaid
flowchart LR
  F["feature/*"] -->|merge| D["develop"]
  D -.->|preview tạm / Dev Tunnel| PV["Preview (local / ephemeral)"]
  D -->|cắt nhánh phát hành| R["release/* — X.Y.Z-rc.N"]
  R -->|deploy| EN["Railway: Nghiệm thu"]
  R -->|merge + tag X.Y.Z| M["main"]
  R -.->|merge-back| D
  M -->|deploy| EM["Railway: Mốc"]
  M -->|giao bản đã tag| PRD["Mini PC offline: Production"]
  M -->|hotfix/* vá gấp| M
```

## Bối cảnh & vấn đề hiện tại

- `main` đang gánh **ba vai**: tích hợp + staging tự deploy + nơi tag release.
- Railway tự deploy mỗi khi push `main` → mọi merge **đè ngay**, kể cả commit chưa có version → không có mốc ổn định.
- **Không có CI, không có branch protection** → release 1.0.1 "đúng" nhờ làm tay, không có gì chặn.

---

## Quyết định (ADR)

### ADR-003: Mô hình nhánh — Git Flow áp cứng
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Phát hành theo phiên bản rời rạc; có cổng khách nghiệm thu; giao bản offline; phải giữ một version ngoài thực địa; team nhỏ, bạn merge.
- **Quyết định:** Git Flow đầy đủ — `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`; thao tác bằng git thường + automation.
- **Lý do:** Khớp đúng ngoại lệ chính tác giả Git Flow nêu: hợp khi "phần mềm được đánh version rõ ràng / cần hỗ trợ nhiều version ngoài thực địa" (xem nguồn nvie ở [Truy vết](#truy-vết)).
- **Tradeoff:** (+) tách rõ 3 môi trường, quy trình cố định dễ dạy, dễ tự động hoá. (−) phải kỷ luật **merge-back** (release/hotfix → *cả* `main` + `develop`); nặng hơn trunk-based; nuôi 2 nhánh sống.
- **Phương án đã loại:** *Trunk-based* (chuẩn 2026 cho đa số) — cần CI mạnh + deploy liên tục (chưa có), không hợp mô hình nghiệm thu/offline. *git-flow CLI (gitflow-avh)* — repo đã archive (rủi ro bỏ rơi).
- **Điều kiện xem lại:** chuyển sang continuous delivery, **hoặc** merge-back thủ công gây lỗi lặp lại → cân nhắc trunk-based + release branch.

### ADR-004: Đánh số version — SemVer + pre-release
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Cần số version truyền đạt đúng mức độ thay đổi; có giai đoạn chờ nghiệm thu.
- **Quyết định:** SemVer `MAJOR.MINOR.PATCH`; bản chờ nghiệm thu dùng `X.Y.Z-rc.N`; chốt mới gắn `X.Y.Z`.
- **Lý do:** Chuẩn phổ biến; pre-release tag là cách chuẩn đánh dấu "đang chờ duyệt, có thể còn sửa".
- **Tradeoff:** (+) rõ ràng, công cụ hỗ trợ sẵn. (−) phải kỷ luật: số đi theo **nội dung** (thêm tính năng → MINOR `1.1.0`, không phải `1.0.2`), không +1 theo môi trường.
- **Phương án đã loại:** đánh số tuần tự tự do — mơ hồ, không truyền đạt mức thay đổi.
- **Điều kiện xem lại:** nếu khách yêu cầu sơ đồ version khác (vd theo ngày).

### ADR-005: Môi trường & promotion
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Railway **tính tiền theo tổng tài nguyên, không theo số environment**. Team có Docker local. Khách ở xa, dùng Railway online.
- **Quyết định:**
  - **Phát triển:** Docker local + preview tạm (VS Code Dev Tunnel / PR env) khi cần — `develop`/`feature/*`.
  - **Nghiệm thu:** 1 Railway env, bật **sleep** — `release/*` → `rc`.
  - **Mốc:** 1 Railway env, bật **sleep** — tag `main` (version đang ở production).
  - **Production:** Mini PC offline — tag `main`.
- **Lý do:** Tách env không đắt hơn gộp → tách cho sạch; sleep + dev local = chi phí gần thấp nhất.
- **Tradeoff:** (+) mỗi version một env riêng, rõ; rẻ. (−) sleep gây cold-start nhẹ khi khách mở lần đầu.
- **Phương án đã loại:** *nhồi 2 app vào 1 env* — loại (dựa trên hiểu nhầm "tính tiền theo env"); *env Phát triển host cố định* — loại (dev chạy local đủ).
- **Điều kiện xem lại:** khách phàn nàn cold-start → tắt sleep env Nghiệm thu; hoặc cần env dev chung host.

### ADR-006: Dữ liệu cho môi trường
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Production offline, khách ở xa → không thể & không cần bơm dữ liệu thật lên Railway.
- **Quyết định:** **Mỗi version dùng seed riêng** (`db/seeds` tại version đó); không ép đồng bộ seed chéo. Đối chiếu là **định tính**.
- **Lý do:** Đơn giản; an toàn (dữ liệu thật không rời mạng offline).
- **Tradeoff:** (+) an toàn, gọn. (−) không phải A/B nghiêm ngặt trên cùng dữ liệu — chấp nhận được vì mục tiêu là nghiệm thu định tính.
- **Phương án đã loại:** *bơm dữ liệu production* — bất khả thi + rủi ro lộ; *ép cùng seed mọi version* — không cần.
- **Điều kiện xem lại:** nếu cần so sánh định lượng chính xác → dựng seed chung có kiểm soát.

### ADR-007: Enforce — miễn phí trước, có đường nâng cấp
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** GitHub branch protection/rulesets **không free cho repo private** (đòi Team ~$4/người/tháng). Repo phải private. Hiện một mình bạn merge.
- **Quyết định:** **Đường miễn phí trước** — CI Actions (test/lint/audit/schema/commitlint + branch-guard native) hiện trạng thái trên PR; release-please cổng-người-duyệt; `/code-review` local. **Đường nâng cấp:** GitHub Team khi cần khoá cứng.
- **Lý do:** Một mình bạn merge → rủi ro bypass gần như không; "quên" thì automation lo. Tiết kiệm tối đa.
- **Tradeoff:** (+) $0, tự động hoá cao. (−) chưa **chặn cứng** ở server (chỉ hiện đỏ) — không thành vấn đề khi 1 người merge.
- **Phương án đã loại:** *GitHub Team ngay* — chưa cần khi 1 người merge; *third-party "Branch Enforcement" Action* — rủi ro bỏ rơi → thay bằng vài dòng bash native.
- **Điều kiện xem lại:** có >1 người được merge, hoặc cần khoá cứng → nâng GitHub Team.

### ADR-008: Release automation — release-please
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Thao tác lặp (bump version, changelog, tag, GitHub Release, merge-back) dễ quên; `gitflow-avh` đã chết.
- **Quyết định:** Dùng **release-please** (Google) — giữ "Release PR", chỉ phát hành khi **bạn merge** (cổng người duyệt); tự bump version + changelog + tag + Release. Cấu hình target `main` (+ release branch khi cần).
- **Lý do:** Maintained (v5.0.0/2026), hỗ trợ release branch, có cổng người duyệt đúng mô hình nghiệm thu.
- **Tradeoff:** (+) tự động hoá phần dễ quên, có cổng duyệt. (−) cần cấu hình để khớp Git Flow (release-please thiên trunk/GitHub-flow).
- **Phương án đã loại:** *semantic-release* — tự release mỗi push, không có cổng → không hợp nghiệm thu; *script tự viết toàn bộ* — tốn công bảo trì.
- **Triển khai (P3, chốt 2026-06-07):** release-please chạy trên `main` lo **bản phát hành chính thức** — release-type `simple`, tag tiền tố `v`, cập nhật `CHANGELOG.md` + `version.txt`, manifest mỏ neo `1.0.1`; đặt `target-branch: main` vì default branch là `develop`. Phần **rc/UAT để dành P4** (chưa có môi trường Nghiệm thu để deploy). Mở rộng branch-source guard cho phép nhánh `release-please--*` vào `main` (Release PR do bot tạo). release-please ghi `CHANGELOG.md`/`version.txt` lên `main` → sau mỗi release phải **đồng bộ `main` → `develop`** (gộp vào merge-back). Dùng `GITHUB_TOKEN` mặc định (miễn phí) — Release PR do bot tạo không tự kích hoạt CI, chấp nhận được vì chỉ sửa changelog/version.
- **Yêu cầu setup (đúc kết khi cắt bản phát hành 1.1.0):**
    - **Cài đặt repository bắt buộc:** phải BẬT tùy chọn "Allow GitHub Actions to create and approve pull requests", nếu không release-please **thất bại** ngay ở bước tạo Release pull request (lỗi: *"GitHub Actions is not permitted to create or approve pull requests"*). Bật bằng: `gh api -X PUT repos/{owner}/{repo}/actions/permissions/workflow -F can_approve_pull_request_reviews=true` (quyền workflow mặc định vẫn để `read` được, vì workflow tự cấp `pull-requests: write` cho chính nó).
    - **Tránh changelog trùng dòng (phương thức merge):** **không có** cài đặt GitHub nào khiến merge commit trở thành "không theo Conventional Commits" — cả ba tổ hợp tiêu đề/nội dung merge hợp lệ đều nhét tiêu đề pull request vào tiêu đề hoặc thân của merge commit; riêng tổ hợp `MERGE_MESSAGE`+`BLANK` bị từ chối với lỗi HTTP 422. Vì vậy pull request loại `feature`/`fix` **phải squash-merge vào `develop`**, nếu không release-please đếm trùng (commit thật + merge commit) và changelog sinh dòng lặp. Repository nay đã đặt `squash_merge_commit_title=PR_TITLE` + `squash_merge_commit_message=BLANK`. Quy ước phương thức merge này đã ghi ở `CONTRIBUTING.md` mục 2 (squash cho `feature`/`fix` vào `develop`; merge commit cho `release/*`/`hotfix/*` và merge-back). Ngoài ra: đặt tiêu đề pull request của `release/*`/`hotfix/*`/merge-back bằng tiền tố **không thuộc loại sinh changelog** (ví dụ `release:`) để merge commit của chúng không thêm dòng changelog lạc.
- **Điều kiện xem lại:** nếu cấu hình release-please + Git Flow quá vướng → cân nhắc semantic-release hoặc script tối giản.

### ADR-009: Review code — AI local + người duyệt
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Muốn AI hỗ trợ review; chỉ soi tay khi AI báo bất thường; tiết kiệm.
- **Quyết định:** Chạy **`/code-review` local trước khi push** (dùng Claude sẵn có, không tốn thêm); bạn duyệt cuối (mô hình B).
- **Lý do:** Đáp đúng nhu cầu, $0 thêm, không phụ thuộc bot trả phí.
- **Tradeoff:** (+) miễn phí, không dependency mới. (−) không tự chạy trên PR (phụ thuộc dev nhớ chạy local).
- **Phương án đã loại:** *PR bot AI tự động (Claude GitHub App)* — tốn token API; để dành khi cần.
- **Điều kiện xem lại:** dev quên chạy review → cân nhắc bot PR tự động.

### ADR-010: Pair local — VS Code Dev Tunnels
- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Cả team dùng VS Code/Cursor; muốn cùng test app đang chạy trên máy nhau **không qua push/deploy**; pair ngắn, không lo lộ lọt; sắp có Windows.
- **Quyết định:** **VS Code Dev Tunnels** (port forwarding tích hợp) — Private mặc định + đăng nhập GitHub. **Cloudflare Tunnel** làm dự phòng (URL ngoài editor / không cần đăng nhập). PR env tạm giữ cho người không phải dev.
- **Lý do:** Sẵn trong editor (0 cài đặt), free, kiểm soát truy cập có sẵn qua GitHub — hợp dự án nội bộ + đa nền tảng.
- **Tradeoff:** (+) gọn nhất cho team VS Code/Cursor. (−) có trang cảnh báo, không custom domain (không quan trọng cho pair).
- **Phương án đã loại:** *Tailscale/VPN* — quá mức cho pair ngắn; *ngrok* — free tier URL đổi mỗi lần; *symlink/nginx* — sai nhu cầu.
- **Điều kiện xem lại:** cần URL ổn định / chia sẻ ngoài team → Cloudflare Tunnel có tên.

### ADR-011: Nội dung CI
- **Trạng thái:** Proposed · 2026-06-07
- **Quyết định:** Workflow CI (free Actions) chạy trên PR: `rspec` (gồm system spec), `rubocop`, `brakeman`, `bundler-audit`, `rails zeitwerk:check`, kiểm schema không lệch, `commitlint`, **branch-source guard** (PR đích `main` mà nguồn ≠ `release/*`/`hotfix/*` → fail).
- **Lý do:** CLAUDE.md yêu cầu rubocop do CI cover; các bước còn lại bắt lỗi sớm; branch-guard ép luật Git Flow (native, không dependency).
- **Tradeoff:** (+) bắt lỗi trước khi tới khách. (−) system spec cần trình duyệt headless trên runner (cấu hình nhỉnh hơn — chi tiết để spec CI riêng).
- **Phân kỳ triển khai (chốt 2026-06-07):** P2 chỉ dựng tập **tĩnh, không cần Postgres/trình duyệt/boot app**: `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, branch-source guard (grandfather vi phạm hiện có để lần CI đầu xanh, không sửa code app). Phần **chạy test** (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng runner/cache/headless chuyển sang mảnh **"CI spec chi tiết"** (Backlog #1) — vì cần dựng dịch vụ Postgres + Chrome headless và quyết định runner/cache mà mảnh đó sở hữu. Lý do tách: tập tĩnh ép được ngay, chi phí thấp, giữ P2 gọn + nhanh; chạy test cần thêm hạ tầng.
- **Triển khai (P5, chốt 2026-06-07):** phần **chạy test** (`rspec` gồm system spec, kiểm schema không lệch, `zeitwerk:check`) cùng runner/cache/headless đã hiện thực ở mảnh "CI spec chi tiết" — xem **ADR-012** trong [`2026-06-07-ci-spec-design.md`](2026-06-07-ci-spec-design.md): runner native `ubuntu-latest` + service container `postgres:16-alpine` + Chrome qua Selenium Manager; một job `tests` gộp schema-drift + zeitwerk + rspec; bật cache gem (đổi luôn job tĩnh sang cache).
- **Điều kiện xem lại:** thời gian CI quá lâu → tách system spec / cache.

---

## Quy trình end-to-end

1. `feature/x` ← `develop`; làm; `/code-review` local; PR vào `develop`; CI xanh + bạn duyệt → merge.
2. Đủ nội dung → `release/1.0` ← `develop`; deploy **Nghiệm thu**; tag `1.0.1-rc.1`.
3. Khách thử → yêu cầu sửa → fix **trên `release/1.0`** → `-rc.2`… (team vẫn chạy `develop`).
4. Khách ưng → release-please tạo Release PR; bạn merge → tag `1.0.1` trên `main` + GitHub Release; giao bản xuống production Mini PC; env **Mốc** = 1.0.1.
5. **Merge-back `release/1.0` → `develop`** (automation lo).
6. Production lỗi gấp → `hotfix/*` ← `main`; vá; tag (vd `1.0.2`); merge về `main` + `develop`.

## Tiêu chí thành công (đo được)

- Cắt & phát hành một version **không có lỗi quên merge-back** (fix không biến mất ở `develop`).
- Mỗi commit trên `main` đều có tag version tương ứng.
- CI bắt được lỗi lint/test/bảo mật **trước khi** tới môi trường Nghiệm thu.
- Khách luôn có **bản Mốc + bản ứng viên** để đối chiếu, production không bị đè ngoài ý muốn.
- Người mới onboarding hiểu quy trình chỉ qua `AGENTS.md` + spec này.

## Rủi ro & giảm thiểu + Rollback

| Rủi ro | Giảm thiểu |
|---|---|
| Quên merge-back | release-please/automation + checklist |
| CI đỏ vẫn merge được (free tier) | 1 người merge + kỷ luật; nâng GitHub Team khi cần |
| Khách không vào được Railway | xác nhận khách có Internet; URL + đăng nhập rõ ràng |
| Sleep cold-start làm khách bối rối | báo trước, hoặc tắt sleep env Nghiệm thu khi có lịch nghiệm thu |
| Lộ dữ liệu | dữ liệu thật **không** rời mạng offline; Railway chỉ seed giả |
| Secrets lộ | biến môi trường để trong Railway variables, không commit |

**Rollback production:** production chạy theo **tag**; gặp sự cố → deploy lại **tag trước đó** trên Mini PC (bản cũ vẫn còn nguyên vì tag không bị xoá). Lỗi cần vá → quy trình `hotfix/*`.

## Checklist phát hành (thực thi, vẫn duyệt tay)

- [ ] CI xanh trên `release/*`.
- [ ] `/code-review` local không còn cảnh báo nghiêm trọng.
- [ ] Ghi chú phát hành tiếng Việt đã biên tập (release-please nháp → biên tập).
- [ ] Khách xác nhận nghiệm thu (với release thường).
- [ ] Merge Release PR → tag trên `main`.
- [ ] **Merge-back về `develop`** đã chạy.
- [ ] Giao bản production Mini PC + cập nhật env Mốc.

## Chi phí

- Railway: rất thấp (app nội bộ ít tải, tính theo phút). 2 env + sleep → vài đô/tháng; dev local $0.
- GitHub: free (CI ≤2000 phút/tháng). Nâng Team chỉ khi cần khoá cứng.
- v1: đã **dừng compute Postgres** (giữ volume + config; ~chỉ tiền lưu trữ).

## Truy vết

- Tài liệu nguồn: `docs/V2_XAC_NHAN_NGHIEP_VU.md`, `V2_THIET_KE_HE_THONG.md`, `V2_HANH_VI_HE_THONG.md`, `V2_CHIEU_TEST.md`, `V2_KICH_BAN_TEST.md`.
- Umbrella: [SDLC Overview](2026-06-07-sdlc-overview-design.md) (ADR-001, ADR-002).
- Nguồn Git Flow: Vincent Driessen, "A successful Git branching model" (ghi chú 2020) — https://nvie.com/posts/a-successful-git-branching-model/

## Backlog

**Mảnh SDLC còn lại (mỗi mảnh 1 spec, làm tuần tự):**
1. **✅ Đã hiện thực** (P5 — ADR-012, [`2026-06-07-ci-spec-design.md`](2026-06-07-ci-spec-design.md)): phần **chạy test trên CI** sau P2 — `rspec` (gồm system spec headless Chrome), kiểm schema không lệch, `rails zeitwerk:check`; runner native + service container Postgres + Chrome qua Selenium Manager; bật cache. (P2 đã dựng tập tĩnh: rubocop/brakeman/bundler-audit/commitlint/branch-source guard — xem ADR-011 "Phân kỳ triển khai".)
2. **✅ Đã hiện thực** (ADR-013..015, [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)): truy vết / quản lý thay đổi (yêu cầu → thiết kế → test → release). Hybrid (GitHub Issues cho luồng + repo cho dấu vết bền); anchor yêu cầu `NV-...` thêm dần + chuẩn hoá mục "Truy vết" của spec; template Issue change-request (`.github/ISSUE_TEMPLATE/change-request.md`) + pull request (`.github/pull_request_template.md`) + ADR (`docs/superpowers/ADR-TEMPLATE.md`); mục 9 trong `CONTRIBUTING.md` + pointer ở `AGENTS.md`.
3. Vận hành / bảo trì (giám sát production offline, backup, tiếp nhận lỗi khách).
4. Tiếp nhận công việc (issue/backlog, ưu tiên).

**Cải tiến optional (chưa làm — YAGNI cho quy mô hiện tại):** cheat-sheet đầu AGENTS.md; checklist onboarding; lint định dạng ADR trong CI; DORA metrics; tách ADR ra `docs/adr/`. *(Template ADR/pull request/issue đã chuyển vào Backlog #2 — ADR-015.)*

## Changelog

- **0.9.0 (2026-06-08):** Backlog #2 ("Truy vết / quản lý thay đổi") đánh dấu **đã hiện thực** — template Issue change-request + pull request + ADR; mục 9 `CONTRIBUTING.md`; pointer `AGENTS.md`. Spec: ADR-013..015 trong [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md).
- **0.8.0 (2026-06-08):** Backlog #2 ("Truy vết / quản lý thay đổi") đánh dấu **thiết kế xong, chờ hiện thực** — trỏ tới spec mới [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) (ADR-013 Hybrid Issues+repo; ADR-014 anchor yêu cầu + truy vết; ADR-015 template Issue/pull request/ADR). Chuyển "template ADR/pull request/issue" từ danh mục optional sang Backlog #2 (ADR-015).
- **0.7.0 (2026-06-07):** Backlog #1 ("CI spec chi tiết") đánh dấu **đã hiện thực** (ADR-012) cho khớp ghi chú "Triển khai (P5)" trong ADR-011 — bỏ mâu thuẫn "còn lại" trong Backlog.
- **0.6.0 (2026-06-07):** ADR-011 thêm ghi chú "Triển khai (P5)" trỏ tới ADR-012 (`2026-06-07-ci-spec-design.md`) — phần chạy test trên CI (rspec/system + kiểm schema không lệch + zeitwerk; runner native + service container Postgres + Chrome qua Selenium Manager; bật cache gem) đã hiện thực.
- **0.5.0 (2026-06-07):** ADR-008 thêm sub-note "Yêu cầu setup" đúc kết khi cắt bản phát hành 1.1.0 — (1) phải bật cài đặt repository "Allow GitHub Actions to create and approve pull requests", nếu không release-please thất bại ở bước tạo Release pull request; (2) `feature`/`fix` phải squash-merge vào `develop` (GitHub không có cách biến merge commit thành "không theo Conventional Commits"; tổ hợp `MERGE_MESSAGE`+`BLANK` bị từ chối HTTP 422) để changelog không trùng dòng — repository đặt `squash_merge_commit_title=PR_TITLE` + `squash_merge_commit_message=BLANK`, và đặt tiêu đề `release/*`/`hotfix/*`/merge-back bằng tiền tố không sinh changelog; trỏ chéo `CONTRIBUTING.md` mục 2.
- **0.4.0 (2026-06-07):** ADR-008 thêm ghi chú triển khai P3: release-please trên `main` (final releases, `simple`, `version.txt`, manifest 1.0.1, `target-branch: main`); guard cho phép `release-please--*`; đồng bộ main→develop sau release; rc để dành P4.
- **0.3.0 (2026-06-07):** ADR-011 thêm "Phân kỳ triển khai" chốt ranh giới P2 (tập tĩnh: rubocop/brakeman/bundler-audit/commitlint/branch-source guard) ↔ mảnh "CI spec chi tiết" (rspec/system + schema-drift + zeitwerk + runner/cache/headless); làm rõ Backlog #1 tương ứng.
- **0.2.0 (2026-06-07):** Viết lại theo ADR-style; thêm Goals/Non-Goals, Glossary, sơ đồ Mermaid, tiêu chí thành công, rủi ro+rollback, truy vết; đổi pairing sang VS Code Dev Tunnels; thêm nguồn nvie; trỏ về SDLC Overview.
- **0.1.0 (2026-06-07):** Bản thảo đầu.
