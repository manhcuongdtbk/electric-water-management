# P4 — Railway Environments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is an **operations runbook** (Railway provisioning + a small docs change), not a code/TDD plan — "tests" are verification commands (`/version`, `environment_status`, deploy logs).

**Goal:** Dựng 3 Railway environment (`development`, `acceptance`, `mirror`) đúng ADR-005 (ghi chú P4), đặt `APPLICATION_ENVIRONMENT_LABEL` tiếng Anh cho từng env, để khách phân biệt và đối chiếu các phiên bản.

**Architecture:** Giữ Git Flow. Ba env auto-deploy 1:1 từ ba nhánh: `develop`→`development`, `main`→`acceptance`, nhánh con trỏ mới `production` (ghim tag `v1.0.0`)→`mirror`. `mirror` là env Railway hiện tại được tái dụng tại chỗ (giữ nguyên dữ liệu). `acceptance` + `development` là bản nhân (duplicate) của env hiện tại. `RAILS_ENV=production` ở cả ba; chỉ `APPLICATION_ENVIRONMENT_LABEL` khác (Mirror/Acceptance/Development). Production thật = Mini PC offline (ngoài phạm vi).

**Tech Stack:** Railway (MCP + dashboard), Git (Git Flow), Rails 8 (`SystemInfo` đọc `APPLICATION_ENVIRONMENT_LABEL`, endpoint `/version`).

---

## Actor legend (đọc trước)

| Ký hiệu | Nghĩa |
|---|---|
| **(MCP)** | Tôi chạy qua Railway MCP tool — *cần bạn cho phép từng call* |
| **(DASH)** | **Bạn** thao tác trong Railway dashboard (MCP không làm được: đổi tên env, chọn nhánh deploy, đặt prefix domain, duyệt staged changes) |
| **(GIT)** | Lệnh git trong worktree; **push cần bạn duyệt** |
| **(VERIFY)** | Bước kiểm chứng — không đổi gì |

> **Hai cổng duyệt bắt buộc:** (1) mọi `git push`; (2) mọi thay đổi tạo/đổi cấu hình trên Railway. Tôi sẽ trình bày trước mỗi cổng.

## Hằng số (ID đã xác minh 2026-06-08)

- Project `electric-water-management`: `bd2f57ad-5fa4-45a0-8209-830e0610fe54`
- Env hiện tại `production` (sẽ thành `mirror`): `1d6d64d6-4cfa-4eb5-b88e-52301ab5e4bb`
- App service `electric-water-management`: `14003ec0-9bff-497e-85d5-968549a9c070`
- Postgres service (env hiện tại): `2bf2d328-5e3c-495a-b58e-db931960bee9`
- Tag ghim cho `mirror`: **`v1.0.0`** (= phiên bản đang ở Mini PC production)
- Project cũ `electric-water-management-v1` (`0ebff64c-...`): **không đụng** (idle)

---

## Task 1: Tạo nhánh con trỏ `production` tại `v1.0.0`

**Files:** không có file repo (thao tác git ref).

- [ ] **Step 1 (GIT): Tạo nhánh local `production` tại tag `v1.0.0`**

```bash
git branch production v1.0.0
git log --oneline -1 production   # phải trỏ đúng commit của tag v1.0.0
```

- [ ] **Step 2 (VERIFY): Xác nhận nhánh không đụng release-please/CI/branch-guard**

`production` không phải đích PR và không phải `main` → `.github/workflows/ci.yml` (chỉ `on: pull_request`) và `release-please.yml` (chỉ `on: push: branches: [main]`) đều **không** chạy. Branch-source guard chỉ xét PR đích `main`. Không cần làm gì.

- [ ] **Step 3 (GIT — CỔNG DUYỆT PUSH): Đẩy nhánh `production` lên origin**

```bash
git push origin production
```

- [ ] **Step 4 (VERIFY): Xác nhận trên remote**

```bash
git ls-remote --heads origin production   # phải in ra ref production = commit v1.0.0
```

---

## Task 2: Nhân (duplicate) env hiện tại thành `development` và `acceptance`

> Nhân **trước khi** tái dụng env gốc, để bản nhân thừa hưởng cấu hình đang trỏ `main`. Bản nhân tạo **staged changes** — phải duyệt trong dashboard mới deploy. Dữ liệu DB của bản nhân là **mới/rỗng** (sẽ tự seed) — đúng ý đồ (acceptance/development cần seed tươi).

**Files:** không có file repo.

- [ ] **Step 1 (MCP): Tạo env `development` (nhân từ env hiện tại)**

Tool `mcp__plugin_railway_railway__create_environment`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
name: development
source_environment_id: 1d6d64d6-4cfa-4eb5-b88e-52301ab5e4bb
```
Ghi lại **environment_id mới của `development`** từ kết quả (gọi là `DEV_ENV_ID`).

- [ ] **Step 2 (MCP): Tạo env `acceptance` (nhân từ env hiện tại)**

Tool `create_environment`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
name: acceptance
source_environment_id: 1d6d64d6-4cfa-4eb5-b88e-52301ab5e4bb
```
Ghi lại **environment_id mới của `acceptance`** (gọi là `ACC_ENV_ID`).

- [ ] **Step 3 (VERIFY): Liệt kê env để xác nhận đã có `development` + `acceptance`**

Tool `environment_status` cho từng env mới (`DEV_ENV_ID`, `ACC_ENV_ID`) → thấy service `electric-water-management` + `Postgres` ở trạng thái staged/chưa deploy.

---

## Task 3: Tái dụng env gốc thành `mirror` (giữ nguyên dữ liệu)

**Files:** không có file repo.

- [ ] **Step 1 (DASH): Đổi tên env `production` → `mirror`**

Railway dashboard → Project `electric-water-management` → Settings → Environments → đổi tên `production` thành `mirror`. (MCP không đổi tên env được.) Env id **không đổi** (`1d6d64d6-...`).

- [ ] **Step 2 (DASH): Đổi nhánh deploy của app service: `main` → `production`**

Vào env `mirror` → service `electric-water-management` → Settings → Source → đổi **trigger branch** thành `production`. **Không** bật "Wait for CI" (CI của ta chỉ chạy trên pull request). Lưu.

- [ ] **Step 3 (MCP): Đặt nhãn môi trường cho `mirror`**

Tool `set_variables`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
environment_id: 1d6d64d6-4cfa-4eb5-b88e-52301ab5e4bb
service_id: 14003ec0-9bff-497e-85d5-968549a9c070
variables: { "APPLICATION_ENVIRONMENT_LABEL": "Mirror" }
```

- [ ] **Step 4 (MCP): Bật sleep cho app service `mirror`**

Tool `update_service`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
environment_id: 1d6d64d6-4cfa-4eb5-b88e-52301ab5e4bb
service_id: 14003ec0-9bff-497e-85d5-968549a9c070
sleep_application: true
```

- [ ] **Step 5 (DASH): Triển khai nhánh `production` lên `mirror`**

Sau khi đổi branch (Step 2), Railway thường tự deploy. Nếu chưa: trong env `mirror`, mở Command Palette (`CMD/CTRL + K`) → **Deploy Latest Commit**. Đây là lúc app chuyển từ `1.1.0` (main) về `v1.0.0` (production branch) trên **cùng database hiện có**.

- [ ] **Step 6 (VERIFY): Deploy thành công + dữ liệu còn nguyên + nhãn đúng**

```bash
# version + nhãn (đổi <mirror-host> theo domain hiện tại của env)
curl -s https://electric-water-management.up.railway.app/version
# Mong đợi: {"version":"1.0.0","application_environment":"Mirror","rails_environment":"production"}
```
- (MCP) `get_logs` (log_type `deploy`) env `mirror` → build/deploy SUCCESS, không lỗi `db:prepare`.
- (Thủ công) Đăng nhập app `mirror`, xác nhận **dữ liệu cũ còn nguyên** (các bản ghi khách đã tạo trên Railway vẫn còn) — đáp ứng yêu cầu "bảo toàn dữ liệu".
- Nếu `/version` vẫn báo `1.1.0`: deploy của `production` branch chưa chạy → quay lại Step 5.

- [ ] **Step 7 (DASH): Thêm domain rõ nghĩa cho `mirror`**

Trong env `mirror` → service → Settings → Networking → Public Networking → thêm/sửa Railway domain prefix thành **`electric-water-management-mirror`** (→ `electric-water-management-mirror.up.railway.app`). Giữ domain trống `electric-water-management.up.railway.app` làm alias (chưa xoá).

- [ ] **Step 8 (VERIFY): Domain mới hoạt động**

```bash
curl -s https://electric-water-management-mirror.up.railway.app/version
# Mong đợi: {"version":"1.0.0","application_environment":"Mirror","rails_environment":"production"}
```

---

## Task 4: Cấu hình env `acceptance` (deploy `main`)

**Files:** không có file repo.

- [ ] **Step 1 (DASH): Chọn nhánh deploy `main` cho `acceptance`**

Env `acceptance` → service `electric-water-management` → Settings → Source → trigger branch = **`main`** (bản nhân đã thừa hưởng `main`; xác nhận lại). Không bật "Wait for CI".

- [ ] **Step 2 (DASH): Duyệt staged changes của `acceptance`**

Trong env `acceptance`, banner staged changes → **Details** → **Deploy** để app + Postgres của env này deploy lần đầu (`db:prepare` sẽ tạo schema + seed vì DB rỗng).

- [ ] **Step 3 (MCP): Đặt nhãn `Acceptance`**

Tool `set_variables`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
environment_id: <ACC_ENV_ID>
service_id: <acceptance app service id — lấy từ list_services của env này>
variables: { "APPLICATION_ENVIRONMENT_LABEL": "Acceptance" }
```

- [ ] **Step 4 (MCP): Bật sleep**

Tool `update_service`: như trên với `sleep_application: true` cho app service của `acceptance`.

- [ ] **Step 5 (VERIFY): DB của bản nhân nối đúng Postgres của chính nó**

(MCP) `get_logs` deploy env `acceptance` → SUCCESS, `db:prepare` chạy được (không lỗi xác thực Postgres). Nếu lỗi kết nối DB (do biến `DATABASE_URL` là literal mang mật khẩu Postgres cũ thay vì reference):
- (MCP) `add_reference_variable` đặt lại biến tham chiếu cho env này, ví dụ:
  ```
  variables: [{ "name": "DATABASE_URL", "value": "${{ Postgres.DATABASE_URL }}" }]
  ```
  rồi deploy lại. (Thường không cần — Railway plugin Postgres đặt sẵn reference.)

- [ ] **Step 6 (DASH): Domain rõ nghĩa cho `acceptance`**

Public Networking → tạo Railway domain prefix **`electric-water-management-acceptance`**.

- [ ] **Step 7 (VERIFY): `/version` của `acceptance`**

```bash
curl -s https://electric-water-management-acceptance.up.railway.app/version
# Mong đợi: {"version":"<phiên bản main hiện tại, vd 1.1.0>","application_environment":"Acceptance","rails_environment":"production"}
```

---

## Task 5: Cấu hình env `development` (deploy `develop`)

**Files:** không có file repo.

- [ ] **Step 1 (DASH): Đổi nhánh deploy sang `develop`**

Env `development` → service → Settings → Source → trigger branch = **`develop`** (đổi từ `main` mà bản nhân thừa hưởng). Không bật "Wait for CI".

- [ ] **Step 2 (DASH): Duyệt staged changes của `development`**

Banner staged changes → Details → Deploy (DB rỗng → `db:prepare` seed).

- [ ] **Step 3 (MCP): Đặt nhãn `Development`**

Tool `set_variables`:
```
project_id: bd2f57ad-5fa4-45a0-8209-830e0610fe54
environment_id: <DEV_ENV_ID>
service_id: <development app service id>
variables: { "APPLICATION_ENVIRONMENT_LABEL": "Development" }
```

- [ ] **Step 4 (MCP): Bật sleep**

Tool `update_service`: `sleep_application: true` cho app service của `development`.

- [ ] **Step 5 (VERIFY): DB nối đúng (như Task 4 Step 5, fallback `add_reference_variable` nếu cần).**

- [ ] **Step 6 (DASH): Domain rõ nghĩa `electric-water-management-development`.**

- [ ] **Step 7 (VERIFY): `/version` của `development`**

```bash
curl -s https://electric-water-management-development.up.railway.app/version
# Mong đợi: {"version":"<phiên bản develop, vd 1.1.0>","application_environment":"Development","rails_environment":"production"}
```

---

## Task 6: Cập nhật `README.md` (3 env + Mini PC = production thật + ghi chú SemVer)

**Files:**
- Modify: `README.md` (mục `## Environments`, `## Staging`, `## Production`)

> Dùng **URL thực** thu được ở Task 3/4/5. Các giá trị dưới là URL dự kiến; chỉnh nếu Railway cấp khác.

- [ ] **Step 1: Đọc lại `README.md` trên nhánh hiện tại** (nội dung trên `develop` có thể khác bản đã xem trên `main`).

Run: đọc file, định vị bảng `## Environments` và hai mục `## Staging`, `## Production`.

- [ ] **Step 2: Thay bảng `## Environments`**

Thay bảng cũ (Development/Staging/Production) bằng:

```markdown
## Environments

| Loại | Hạ tầng | Nguồn deploy | Nhãn (`APPLICATION_ENVIRONMENT_LABEL`) | URL |
|---|---|---|---|---|
| Phát triển (local) | Docker Desktop | `develop`/`feature/*` (máy bạn) | (không) | http://localhost |
| Railway `development` | Railway (sleep) | nhánh `develop` (tự deploy) | `Development` | https://electric-water-management-development.up.railway.app |
| Railway `acceptance` | Railway (sleep) | nhánh `main` (tự deploy) | `Acceptance` | https://electric-water-management-acceptance.up.railway.app |
| Railway `mirror` | Railway (sleep) | nhánh `production` (ghim tag đã giao) | `Mirror` | https://electric-water-management-mirror.up.railway.app |
| **Production (thật)** | Ubuntu Mini PC (LAN offline) | tag `main` đã giao | `Production` (đặt tại Mini PC) | http://\<IP server\> |

> Cả ba env Railway và Mini PC đều chạy `RAILS_ENV=production`; chỉ `APPLICATION_ENVIRONMENT_LABEL` khác nhau để phân biệt (xem mục "environment terminology" trong `AGENTS.md`). **Production thật là Mini PC offline tại chỗ khách**, không phải Railway. `mirror` là bản sinh đôi *online* của Production để khách đối chiếu với `acceptance` (bản ứng viên).
```

- [ ] **Step 3: Thay mục `## Staging`** (cũ: "Railway auto-deploy khi push branch main…") bằng:

```markdown
## Railway (development / acceptance / mirror)

Ba environment trên Railway (đều bật sleep) tự deploy theo nhánh: `develop`→`development`, `main`→`acceptance`, nhánh con trỏ `production`→`mirror`. Chi tiết và lý do: ADR-005 (ghi chú "Triển khai & điều chỉnh (P4)") trong `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.
```

- [ ] **Step 4: Bổ sung ghi chú version vào mục `## Production`** (giữ nội dung Mini PC, thêm 1 dòng):

```markdown
> **Phiên bản:** repo này là **hệ thống v2**, nhưng version phần mềm theo **SemVer từ `1.0.0`** (số MAJOR mang nghĩa tương thích/breaking, không phải "đời sản phẩm"). Hệ thống v1 nằm ở project Railway riêng. Phiên bản đang chạy ở Production hiện tại: `v1.0.0`.
```

- [ ] **Step 5 (VERIFY): Kiểm tra README đọc xuôi**

Run: đọc lại mục đã sửa; không còn từ "Staging" lẻ loi mâu thuẫn; URL khớp env đã dựng.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: describe three Railway environments and production version

Replace the single Staging row with development/acceptance/mirror, mark the
Mini PC as the real production, and note this repository is system v2
versioned with SemVer from 1.0.0.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Kiểm chứng toàn cục + mở pull request

- [ ] **Step 1 (VERIFY): Ba `/version` đồng thời, nhãn đúng, version đúng**

```bash
for h in development acceptance mirror; do
  echo "== $h =="; curl -s https://electric-water-management-$h.up.railway.app/version; echo
done
# development: application_environment=Development, version=<develop>
# acceptance:  application_environment=Acceptance,  version=<main>
# mirror:      application_environment=Mirror,      version=1.0.0
```

- [ ] **Step 2 (VERIFY): Nhãn hiện ở trang đăng nhập (trước khi đăng nhập)**

Mở mỗi URL `/users/sign_in` (hoặc trang gốc) → thấy dòng `v… · Development|Acceptance|Mirror` dưới phụ đề (tính năng version-reporting đã merge). Xác nhận 3 env phân biệt được.

- [ ] **Step 3 (VERIFY): Sleep đã bật cả ba**

(MCP) `get_service_config` từng app service → xác nhận sleep on. Hoặc kiểm trong dashboard service Settings.

- [ ] **Step 4 (VERIFY): Auto-deploy hoạt động (kiểm thử nhẹ, tùy chọn)**

Đẩy một commit nhỏ vô hại lên `develop` → xác nhận env `development` tự deploy lại (xem `list_deployments`). (Bỏ qua nếu không muốn tạo commit thử.)

- [ ] **Step 5 (GIT — CỔNG DUYỆT PUSH): Đẩy nhánh tài liệu**

```bash
git push -u origin docs/p4-railway-environments
```

- [ ] **Step 6 (GIT): Mở pull request vào `develop`** (Conventional Commits, tiếng Anh)

```bash
gh pr create --base develop --head docs/p4-railway-environments \
  --title "docs(release): record P4 Railway environments setup" \
  --body "$(cat <<'EOF'
## Tóm tắt
Ghi nhận thiết kế P4 (môi trường Railway) và cập nhật README.

- Spec: cập nhật ADR-005 (+ ADR-008/004) trong quy-trinh-release-design.md (3 env tiếng Anh development/acceptance/mirror; acceptance←main không rc; mirror←nhánh con trỏ production ghim tag đã giao; thêm development; hai trục danh tính vs RAILS_ENV; sleep; giữ data mirror; lý do tập-con tầng chuẩn). Bump 0.7.0→0.8.0.
- README: 3 env + URL, Mini PC = production thật, ghi chú hệ thống v2 / SemVer từ 1.0.0.

## Hạ tầng (đã thực hiện trên Railway, ngoài repo)
- Tái dụng env hiện tại → `mirror` (nhánh `production` ghim v1.0.0, giữ data, sleep, nhãn Mirror).
- Tạo `acceptance` (←main) + `development` (←develop), sleep, nhãn tương ứng.
- URL: electric-water-management-{development,acceptance,mirror}.up.railway.app.

## Test plan
- [ ] `/version` ba env trả đúng version + application_environment (Development/Acceptance/Mirror), rails_environment=production.
- [ ] Nhãn hiện ở trang đăng nhập cả ba env.
- [ ] mirror giữ nguyên dữ liệu cũ; deploy v1.0.0 SUCCESS.
- [ ] Sleep bật cả ba.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7 (VERIFY): CI xanh trên PR + đánh dấu hết test plan trước khi merge** (merge do bạn duyệt; squash vào `develop` theo CONTRIBUTING §2).

---

## Self-review — đối chiếu plan ↔ spec (ADR-005 ghi chú P4)

| Yêu cầu trong spec | Task |
|---|---|
| 3 env tiếng Anh trong project sẵn có | Task 2, 3 |
| `mirror` ← nhánh `production` ghim `v1.0.0`, giữ data | Task 1, 3 |
| `acceptance` ← `main` (không rc) | Task 4 |
| `development` ← `develop` | Task 5 |
| `APPLICATION_ENVIRONMENT_LABEL` = Mirror/Acceptance/Development | Task 3.3, 4.3, 5.3 |
| `RAILS_ENV=production` cả ba (không đụng) | Mặc định env hiện tại + bản nhân — không đổi |
| Sleep bật cả ba | Task 3.4, 4.4, 5.4 |
| URL `…-{development,acceptance,mirror}` | Task 3.7, 4.6, 5.6 |
| Không đụng project v1 | Hằng số (ghi rõ) |
| README phản ánh 3 env + Mini PC production + SemVer v2 | Task 6 |
| Không push/đổi Railway khi chưa duyệt | Cổng duyệt ở Task 1.3, 3, 7.5 |

**Lưu ý rủi ro thực thi:**
- Nếu `create_environment` (duplicate) không sao chép biến tham chiếu DB đúng → bản nhân không nối được Postgres riêng → dùng `add_reference_variable` (Task 4.5/5.5).
- Nếu deploy `v1.0.0` lên `mirror` build lỗi (khác builder/railway.json giữa v1.0.0 và nay) → xem `get_logs build`, xử lý theo log; báo lại trước khi sửa cấu hình ngoài kế hoạch.
- `mirror` đổi từ 1.1.0 → v1.0.0 trên cùng DB: an toàn vì schema y hệt (26 migration cả hai); `db:prepare` không seed lại DB đã có dữ liệu.
