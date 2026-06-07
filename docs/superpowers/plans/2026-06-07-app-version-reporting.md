# Application Self-Version Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Trạng thái:** ĐÃ THỰC THI và mở PR (#282). Tài liệu này đã được **đồng bộ với code cuối cùng + spec v0.8.0** — phản ánh đúng cái đã build (không còn là bản nháp ban đầu). Nguồn sự thật: spec `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md` và code đã merge.

**Goal:** Let the running app report its own version (from `version.txt`) plus an application-environment label across four surfaces — sidebar/login UI, a public `/version` JSON endpoint, log tags, and the Excel export footer.

**Architecture:** `SystemInfo` (a stateless module in `lib/`) is the single source of truth: it reads `version.txt` once at load into `SystemInfo::VERSION` and exposes `version`, `application_environment`, `to_h`, `log_tag`. No app-name-coupled constant (rename-safe). The application-environment label comes from `ENV["APPLICATION_ENVIRONMENT_LABEL"]`, falling back to `Rails.env.capitalize` (English on purpose — a deployment identifier, distinct from `Rails.env`). A small initializer only logs a tagged startup line.

**Tech Stack:** Rails 8, RSpec + Capybara, caxlsx (Excel), Devise (auth), Tailwind (UI). Tests run via `bin/docker rspec`.

**Design spec:** `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md` (approved, v0.8.0).

**Terminology:** "application environment" (deployment label, `SystemInfo.application_environment`) is distinct from "Rails environment" (`Rails.env`). See the glossary in `AGENTS.md`.

**Conventions:** Code/commits in English (Conventional Commits), UI/docs in Vietnamese. **No abbreviations** (identifiers fully spelled: `application_environment`, `rails_environment`, `APPLICATION_ENVIRONMENT_LABEL`). End every commit message with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. The Excel footer label is routed through i18n (`config/locales/vi.yml` → `system_info.excel_footer`); the sidebar/login show only `vX.Y.Z` + the English application-environment label (no Vietnamese chrome).

---

## File Structure

**Create:**
- `config/initializers/version.rb` — logs one tagged startup line (the version read itself lives in `SystemInfo`).
- `lib/system_info.rb` — `SystemInfo` module (single source of truth; owns the `version.txt` read into `SystemInfo::VERSION`).
- `app/controllers/version_controller.rb` — public `/version` JSON endpoint.
- `spec/lib/system_info_spec.rb` — unit spec for `SystemInfo`.
- `spec/requests/version_spec.rb` — endpoint + sidebar + login presence specs.

**Modify:**
- `config/routes.rb` — add the `/version` route.
- `config/environments/production.rb` — add the version+environment lambda to `config.log_tags`.
- `config/locales/vi.yml` — add the `system_info.excel_footer` i18n key.
- `app/views/layouts/_sidebar.html.erb` — pin a one-line version block at the bottom.
- `app/views/devise/sessions/new.html.erb` — add a version line under the subtitle.
- `app/views/billing/show.xlsx.axlsx` — add a version footer row below the table (label via i18n).
- `spec/requests/billing_spec.rb` — assert the Excel version stamp.

---

## Task 1: `SystemInfo` module + version

**Files:**
- Create: `lib/system_info.rb`
- Create: `config/initializers/version.rb`
- Test: `spec/lib/system_info_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/lib/system_info_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SystemInfo do
  describe ".version" do
    it "trả về hằng số VERSION đã đóng băng" do
      expect(described_class.version).to equal(SystemInfo::VERSION)
      expect(SystemInfo::VERSION).to be_frozen
    end

    it "khớp nội dung version.txt ở gốc repo" do
      expected = File.read(Rails.root.join("version.txt")).strip
      expect(described_class.version).to eq(expected)
    end
  end

  describe ".application_environment" do
    before { allow(ENV).to receive(:[]).and_call_original }

    it "dùng APPLICATION_ENVIRONMENT_LABEL khi được đặt" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.application_environment).to eq("Acceptance")
    end

    it "cắt khoảng trắng thừa của APPLICATION_ENVIRONMENT_LABEL" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("  Mirror  ")
      expect(described_class.application_environment).to eq("Mirror")
    end

    it "dự phòng Rails.env.capitalize khi biến trống" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return(nil)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(described_class.application_environment).to eq("Production")
    end
  end

  describe ".to_h" do
    it "trả version, application_environment, rails_environment" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return(nil)
      expect(described_class.to_h).to eq(
        version: SystemInfo::VERSION,
        application_environment: Rails.env.to_s.capitalize,
        rails_environment: Rails.env.to_s
      )
    end
  end

  describe ".log_tag" do
    it "gộp phiên bản và môi trường thành một tag" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.log_tag).to eq("v#{SystemInfo::VERSION} Acceptance")
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/lib/system_info_spec.rb`
Expected: FAIL with `uninitialized constant SystemInfo`.

- [ ] **Step 3: Create the `SystemInfo` module (owns the version read)**

Create `lib/system_info.rb`:

```ruby
# Nguồn sự thật duy nhất cho phiên bản + môi trường ứng dụng (application environment) đang chạy.
# Module (namespace không trạng thái, không khởi tạo) — view, endpoint, Excel và log đều gọi tới đây.
# Đặt ở lib/ (mối quan tâm hạ tầng) để app/services/ thuần class domain.
#
# Phân biệt (xem glossary trong AGENTS.md):
#   - application_environment: nhãn NƠI triển khai (Acceptance / Mirror / Production…), do ops đặt.
#   - Rails.env (rails_environment): chế độ runtime của Rails (development / test / production).
# Hai cái có thể khác nhau (vd Nghiệm thu và Mốc đều rails_environment=production, application_environment khác).
module SystemInfo
  # Đọc version.txt (do release-please quản lý) một lần khi nạp module.
  # Thiếu file hoặc file rỗng → "unknown" để ứng dụng vẫn khởi động được.
  version_file = Rails.root.join("version.txt")
  VERSION = ((File.exist?(version_file) ? File.read(version_file).strip.presence : nil) || "unknown").freeze

  def self.version
    VERSION
  end

  # Môi trường ứng dụng (application environment) — nhãn tiếng Anh cho nơi triển khai.
  # Ops đặt APPLICATION_ENVIRONMENT_LABEL cho từng nơi; trống → Rails.env.capitalize.
  def self.application_environment
    ENV["APPLICATION_ENVIRONMENT_LABEL"]&.strip.presence || Rails.env.to_s.capitalize
  end

  def self.to_h
    { version: version, application_environment: application_environment, rails_environment: Rails.env.to_s }
  end

  # Một tag gộp cho log: "v1.0.1 Production".
  def self.log_tag
    "v#{version} #{application_environment}"
  end
end
```

- [ ] **Step 4: Create the startup-log initializer**

Create `config/initializers/version.rb` (only logs; does NOT define the version constant — that lives in `SystemInfo`, so nothing depends on the app's literal module name):

```ruby
# Ghi một dòng log khởi động kèm phiên bản + môi trường để truy vết bản phát hành.
# Phiên bản được đọc trong SystemInfo (lib/system_info.rb) — nguồn sự thật duy nhất.
# Dùng after_initialize để SystemInfo đã sẵn sàng; lấy tên app động (module_parent_name)
# để không hard-code tên app, an toàn khi đổi tên sau này.
Rails.application.config.after_initialize do
  Rails.logger.info(
    "Booting #{Rails.application.class.module_parent_name} version=#{SystemInfo.version} " \
    "application_environment=#{SystemInfo.application_environment} rails_environment=#{Rails.env}"
  )
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/docker rspec spec/lib/system_info_spec.rb`
Expected: PASS (7 examples, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add config/initializers/version.rb lib/system_info.rb spec/lib/system_info_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): read app version into a SystemInfo module

SystemInfo (lib/) reads version.txt once into SystemInfo::VERSION and
exposes version + application environment as the single source of truth
(no app-name-coupled constant). An initializer logs a tagged startup line.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Public `/version` JSON endpoint

**Files:**
- Create: `app/controllers/version_controller.rb`
- Modify: `config/routes.rb` (after the `up` health route)
- Test: `spec/requests/version_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/requests/version_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Version", type: :request do
  describe "GET /version" do
    it "trả JSON phiên bản, không cần đăng nhập" do
      get "/version"

      expect(response).to have_http_status(:ok)
      expect(response).not_to have_http_status(:redirect)
      expect(response.media_type).to eq("application/json")
      body = JSON.parse(response.body)
      expect(body["version"]).to eq(SystemInfo.version)
      expect(body["application_environment"]).to eq(SystemInfo.application_environment)
      expect(body["rails_environment"]).to eq(Rails.env.to_s)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/version_spec.rb`
Expected: FAIL (no route / 404).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add the version route immediately after the existing health-check line:

```ruby
  get "up" => "rails/health#show", as: :rails_health_check
  get "version" => "version#show", as: :app_version
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/version_controller.rb`:

```ruby
# Endpoint công khai để script deploy / bộ phận hỗ trợ xác minh bản đang chạy.
# Kế thừa ActionController::Base trực tiếp: không cần đăng nhập, không vướng
# before_action của ApplicationController (authenticate_user!, enforce_password_change...).
class VersionController < ActionController::Base
  def show
    render json: SystemInfo.to_h
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/version_spec.rb`
Expected: PASS (1 example, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/version_controller.rb config/routes.rb spec/requests/version_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): add public /version JSON endpoint

GET /version returns {version, application_environment, rails_environment}
without authentication so deploy automation and support can verify the
running release (including the offline Mini PC).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Tag logs with version + environment

**Files:**
- Modify: `config/environments/production.rb`

The log-tag *content* is already unit-tested via `SystemInfo.log_tag` (Task 1). This task wires that content into the production logger. The lambda is evaluated per-request at runtime, so `SystemInfo` is available by then.

- [ ] **Step 1: Edit the log_tags configuration**

In `config/environments/production.rb`, replace the existing line:

```ruby
  config.log_tags = [ :request_id ]
```

with:

```ruby
  # Gắn phiên bản + môi trường vào mọi dòng log (request + báo cáo lỗi) để truy vết
  # bản phát hành và phân biệt môi trường. Lambda chạy theo từng request lúc runtime,
  # nên hằng số/SystemInfo đã sẵn sàng dù initializer chạy sau file này.
  config.log_tags = [ ->(_request) { SystemInfo.log_tag }, :request_id ]
```

- [ ] **Step 2: Verify the lambda produces the expected tag**

Run: `bin/docker exec -e RAILS_ENV=production -e SECRET_KEY_BASE=dummy app bin/rails runner "puts Rails.application.config.log_tags.first.call(nil)"`
Expected output: `v<version> Production` (e.g. `v1.0.1 Production`).

If the production environment cannot boot inside the dev container, skip — `SystemInfo.log_tag` correctness is already covered by `spec/lib/system_info_spec.rb`, and this step is only wiring.

- [ ] **Step 3: Commit**

```bash
git add config/environments/production.rb
git commit -m "$(cat <<'EOF'
feat(version): tag production logs with version and environment

Prepend "v<version> <application environment>" to every production log line
(request logs and error reports) so a bug reported from an offline Mini PC
traces to a release, and logs aggregated across the two Railway environments
stay distinguishable.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Version display at the bottom of the sidebar

**Files:**
- Modify: `app/views/layouts/_sidebar.html.erb`
- Test: `spec/requests/version_spec.rb` (add a context)

- [ ] **Step 1: Add the failing presence test**

In `spec/requests/version_spec.rb`, add this `describe` block inside the top-level `RSpec.describe "Version", type: :request do ... end`, after the existing `GET /version` block:

```ruby
  describe "hiển thị phiên bản ở sidebar" do
    let(:user) { create(:user, :system_admin) }
    before { sign_in user }

    it "hiện phiên bản ở đáy sidebar trên trang đã đăng nhập" do
      get users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("v#{SystemInfo.version}")
      expect(response.body).to include(SystemInfo.application_environment)
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "đáy sidebar"`
Expected: FAIL — body does not include the version string yet.

- [ ] **Step 3: Restructure the sidebar and add the one-line version block**

Replace the entire contents of `app/views/layouts/_sidebar.html.erb` with:

```erb
<aside class="bg-white border-r border-gray-200 flex-shrink-0 flex flex-col">
  <nav class="px-3 py-3 space-y-4 flex-1 overflow-y-auto">
    <% sidebar_groups.each do |group| %>
      <div>
        <h3 class="text-[11px] font-bold uppercase text-gray-400 mb-1 tracking-wider"><%= group[:label] %></h3>
        <ul class="space-y-0.5">
          <% group[:items].each do |item| %>
            <li>
              <%= link_to item[:label], item[:path], class: sidebar_item_class(item[:path]) %>
            </li>
          <% end %>
        </ul>
      </div>
    <% end %>
  </nav>
  <div class="px-3 py-2 border-t border-gray-100 text-[11px] text-gray-400 whitespace-nowrap">
    v<%= SystemInfo.version %> · <%= SystemInfo.application_environment %>
  </div>
</aside>
```

Note: `overflow-y-auto` moved from `<aside>` onto `<nav>` (now `flex-1`) so the nav scrolls internally while the one-line version block stays pinned at the bottom. `whitespace-nowrap` keeps it on one line in the narrow sidebar.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "đáy sidebar"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/_sidebar.html.erb spec/requests/version_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): show version and environment at the sidebar bottom

Pin a compact one-line block (version · application environment) to the
bottom of the sidebar so the running release is visible on every page after
login — key for telling the near-identical Railway environments apart.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Version display on the login screen

**Files:**
- Modify: `app/views/devise/sessions/new.html.erb`
- Test: `spec/requests/version_spec.rb` (add a context)

- [ ] **Step 1: Add the failing presence test**

In `spec/requests/version_spec.rb`, add this `describe` block inside the top-level `RSpec.describe "Version", type: :request do ... end`:

```ruby
  describe "hiển thị phiên bản ở màn hình đăng nhập" do
    it "hiện phiên bản trên trang đăng nhập (chưa đăng nhập)" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("v#{SystemInfo.version}")
      expect(response.body).to include(SystemInfo.application_environment)
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "màn hình đăng nhập"`
Expected: FAIL — login body does not include the version string yet.

- [ ] **Step 3: Add the version line under the subtitle**

In `app/views/devise/sessions/new.html.erb`, replace this line:

```erb
  <p class="text-sm text-gray-600 mb-6">Hệ thống quản lý điện nội bộ Sư đoàn</p>
```

with these two lines (subtitle margin tightened, version line added below — single line is fine since the login card is not width-constrained):

```erb
  <p class="text-sm text-gray-600 mb-1">Hệ thống quản lý điện nội bộ Sư đoàn</p>
  <p class="text-xs text-gray-400 mb-6">v<%= SystemInfo.version %> · <%= SystemInfo.application_environment %></p>
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "màn hình đăng nhập"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/devise/sessions/new.html.erb spec/requests/version_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): show version and environment on the login screen

Add a muted version + application-environment line under the login subtitle
so testers can identify the release and environment before signing in.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Stamp the version into the Excel export

**Files:**
- Modify: `config/locales/vi.yml` (add the footer i18n key)
- Modify: `app/views/billing/show.xlsx.axlsx` (near the end, before `sheet.column_widths`)
- Test: `spec/requests/billing_spec.rb` (add to the `"format :xlsx"` → `"SA (30 cột)"` context)

- [ ] **Step 1: Add the failing test**

In `spec/requests/billing_spec.rb`, inside `context "SA (30 cột)" do` (the block starting at `let(:user) { create(:user, :system_admin) }`), add this example:

```ruby
        it "đóng dấu phiên bản hệ thống ở chân file" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" ")
          expect(all_text).to include("Phiên bản hệ thống")
          expect(all_text).to include("v#{SystemInfo.version}")
        end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "đóng dấu phiên bản"`
Expected: FAIL — the version string is not in the workbook yet.

- [ ] **Step 3: Add the i18n key**

In `config/locales/vi.yml`, add under the top-level `vi:` (e.g. right after the `application:` block):

```yaml
  system_info:
    excel_footer: "Phiên bản hệ thống: v%{version} · Môi trường ứng dụng: %{application_environment}"
```

(Label "Môi trường ứng dụng" — không phải chỉ "Môi trường" — để không nhầm với Rails environment.)

- [ ] **Step 4: Add the version footer row**

In `app/views/billing/show.xlsx.axlsx`, find the final line inside the worksheet block:

```ruby
    sheet.column_widths(*Array.new(total_columns, 14))
```

Insert the version footer rows immediately *before* it, so that section reads:

```ruby
    # Đóng dấu phiên bản để truy vết file xuất về đúng bản phát hành.
    # Một ô ở cột A, dưới dòng TỔNG — không merge nên không phá cấu trúc bảng.
    sheet.add_row []
    version_style = wb.styles.add_style(sz: 9, i: true, fg_color: "9CA3AF")
    sheet.add_row [I18n.t("system_info.excel_footer", version: SystemInfo.version, application_environment: SystemInfo.application_environment)],
                  style: [version_style]

    sheet.column_widths(*Array.new(total_columns, 14))
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "đóng dấu phiên bản"`
Expected: PASS. Also run the full billing spec to ensure no regression: `bin/docker rspec spec/requests/billing_spec.rb`.

- [ ] **Step 6: Commit**

```bash
git add config/locales/vi.yml app/views/billing/show.xlsx.axlsx spec/requests/billing_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): stamp version and environment into Excel export footer

Add a small footer row below the totals row of the billing workbook (label
via i18n system_info.excel_footer) so an exported report can be traced back
to the release that produced it.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Full suite + visual verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bin/docker rspec`
Expected: all examples pass (0 failures). If anything fails, fix it before proceeding.

- [ ] **Step 2: Start the dev server for visual checks**

Use `preview_start` with server name `docker-dev` (per `.claude/launch.json`). Do not run `docker compose` manually.

- [ ] **Step 3: Verify the login screen shows the version**

Navigate to the login page (`/users/sign_in`). Take a `preview_screenshot`. Confirm the line `v<version> · <application environment>` appears under the subtitle.

- [ ] **Step 4: Verify the sidebar shows the version**

Sign in, then `preview_snapshot`/`preview_screenshot` of any page. Confirm the one-line version block (`v<version> · <application environment>`) is pinned at the bottom of the sidebar.

- [ ] **Step 5: Verify the endpoint**

`preview_eval`: `await fetch('/version').then(r => r.json())`. Confirm it returns `{version, application_environment, rails_environment}` with the expected version.

- [ ] **Step 6: Final commit (if any verification fixes were needed)**

Only if Steps 3–5 surfaced issues that required code changes; otherwise skip. Commit with an appropriate `fix(version): ...` message ending in the `Co-Authored-By` trailer.

---

## Self-Review notes (reconciled against the spec)

- **Spec coverage:** version read in `SystemInfo` (Task 1) · `SystemInfo` single source (Task 1) · `/version` JSON public (Task 2) · log tag version+environment (Tasks 1+3) · sidebar one-line (Task 4) · login (Task 5) · Excel footer via i18n (Task 6) · English `application_environment` + `APPLICATION_ENVIRONMENT_LABEL` fallback (Task 1) · tests per surface (each task) · full suite (Task 7).
- **No admin "system info" page**, per the approved spec (dropped as YAGNI).
- **i18n:** the Excel footer label uses `system_info.excel_footer` ("Môi trường ứng dụng" to avoid confusion with Rails environment); the sidebar/login carry only `vX.Y.Z` + the English application-environment label.
- **Identifier names consistent across tasks:** `SystemInfo.version`, `.application_environment`, `.to_h`, `.log_tag`; constant `SystemInfo::VERSION`; JSON keys `version` / `application_environment` / `rails_environment`; env var `APPLICATION_ENVIRONMENT_LABEL`. Fully spelled (no abbreviations).
- **Rename-safe:** no `AppModule::VERSION` constant; startup log uses `Rails.application.class.module_parent_name`.
- **Ops follow-up (P4):** set `APPLICATION_ENVIRONMENT_LABEL` (English) on each Railway environment and the Mini PC. Out of scope for this plan.
