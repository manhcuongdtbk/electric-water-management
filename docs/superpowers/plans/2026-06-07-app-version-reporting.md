# Application Self-Version Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the running app report its own version (from `version.txt`) plus an environment label across four surfaces — sidebar/login UI, a public `/version` JSON endpoint, log tags, and the Excel export footer.

**Architecture:** Read `version.txt` once at boot into `ElectricWaterManagement::VERSION` (an initializer). A stateless `SystemInfo` module in `lib/` is the single source every surface reads (`version`, `environment_label`, `to_h`, `log_tag`). The environment label comes from `ENV["APP_ENVIRONMENT_LABEL"]`, falling back to `Rails.env.capitalize` (English on purpose — it is a deployment identifier).

**Tech Stack:** Rails 8, RSpec + Capybara, caxlsx (Excel), Devise (auth), Tailwind (UI). Tests run via `bin/docker rspec`.

**Design spec:** `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md` (approved, v0.3.0).

**Conventions:** Code/commits in English (Conventional Commits), UI/docs in Vietnamese. No abbreviations. End every commit message with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. The Excel template (`show.xlsx.axlsx`) hardcodes Vietnamese strings already — match that pattern (no new i18n keys needed; the sidebar/login show only `vX.Y.Z` + the English env label, so they need no Vietnamese chrome).

---

## File Structure

**Create:**
- `config/initializers/version.rb` — defines `ElectricWaterManagement::VERSION`; logs one startup line.
- `lib/system_info.rb` — `SystemInfo` module (single source of truth).
- `app/controllers/version_controller.rb` — public `/version` JSON endpoint.
- `spec/lib/system_info_spec.rb` — unit spec for `SystemInfo`.
- `spec/requests/version_spec.rb` — endpoint + sidebar + login presence specs.

**Modify:**
- `config/routes.rb` — add the `/version` route.
- `config/environments/production.rb` — add version+environment to `config.log_tags`.
- `app/views/layouts/_sidebar.html.erb` — pin a two-line version block at the bottom.
- `app/views/devise/sessions/new.html.erb` — add a version line under the subtitle.
- `app/views/billing/show.xlsx.axlsx` — add a version footer row below the table.
- `spec/requests/billing_spec.rb` — assert the Excel version stamp.

---

## Task 1: `SystemInfo` module + version constant

**Files:**
- Create: `config/initializers/version.rb`
- Create: `lib/system_info.rb`
- Test: `spec/lib/system_info_spec.rb`

- [ ] **Step 1: Write the failing test**

Create `spec/lib/system_info_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe SystemInfo do
  describe ".version" do
    it "trả về hằng số phiên bản đọc từ version.txt" do
      expect(described_class.version).to eq(ElectricWaterManagement::VERSION)
    end

    it "khớp nội dung version.txt ở gốc repo" do
      expected = File.read(Rails.root.join("version.txt")).strip
      expect(described_class.version).to eq(expected)
    end
  end

  describe ".environment_label" do
    before { allow(ENV).to receive(:[]).and_call_original }

    it "dùng APP_ENVIRONMENT_LABEL khi được đặt" do
      allow(ENV).to receive(:[]).with("APP_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.environment_label).to eq("Acceptance")
    end

    it "cắt khoảng trắng thừa của APP_ENVIRONMENT_LABEL" do
      allow(ENV).to receive(:[]).with("APP_ENVIRONMENT_LABEL").and_return("  Mirror  ")
      expect(described_class.environment_label).to eq("Mirror")
    end

    it "dự phòng Rails.env.capitalize khi biến trống" do
      allow(ENV).to receive(:[]).with("APP_ENVIRONMENT_LABEL").and_return(nil)
      expect(described_class.environment_label).to eq(Rails.env.to_s.capitalize)
    end
  end

  describe ".to_h" do
    it "trả version, environment, rails_env" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APP_ENVIRONMENT_LABEL").and_return(nil)
      expect(described_class.to_h).to eq(
        version: ElectricWaterManagement::VERSION,
        environment: Rails.env.to_s.capitalize,
        rails_env: Rails.env
      )
    end
  end

  describe ".log_tag" do
    it "gộp phiên bản và môi trường thành một tag" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APP_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.log_tag).to eq("v#{ElectricWaterManagement::VERSION} Acceptance")
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/lib/system_info_spec.rb`
Expected: FAIL with `uninitialized constant SystemInfo`.

- [ ] **Step 3: Create the version constant initializer**

Create `config/initializers/version.rb`:

```ruby
# Đọc phiên bản ứng dụng từ version.txt (do release-please quản lý) một lần lúc khởi động.
# Thiếu file hoặc file rỗng → "unknown" để ứng dụng vẫn khởi động được.
module ElectricWaterManagement
  version_file = Rails.root.join("version.txt")
  VERSION = ((File.exist?(version_file) ? File.read(version_file).strip.presence : nil) || "unknown").freeze
end

# Ghi một dòng log khởi động kèm phiên bản + môi trường để truy vết bản phát hành.
# Dùng after_initialize để SystemInfo (lib/) đã sẵn sàng, tránh autoload lúc khởi tạo.
Rails.application.config.after_initialize do
  Rails.logger.info(
    "Booting ElectricWaterManagement version=#{ElectricWaterManagement::VERSION} " \
    "environment=#{SystemInfo.environment_label} rails_env=#{Rails.env}"
  )
end
```

- [ ] **Step 4: Create the `SystemInfo` module**

Create `lib/system_info.rb`:

```ruby
# Nguồn sự thật duy nhất cho phiên bản + nhãn môi trường của ứng dụng đang chạy.
# Module không trạng thái: view, endpoint, Excel và log đều gọi tới đây.
# Đặt ở lib/ (mối quan tâm hạ tầng) để app/services/ thuần class domain.
module SystemInfo
  module_function

  def version
    ElectricWaterManagement::VERSION
  end

  # Nhãn môi trường là tiếng Anh (định danh triển khai). Ops đặt APP_ENVIRONMENT_LABEL
  # cho từng nơi triển khai (ví dụ Acceptance / Mirror / Production); trống → Rails.env.
  def environment_label
    ENV["APP_ENVIRONMENT_LABEL"]&.strip.presence || Rails.env.to_s.capitalize
  end

  def to_h
    { version: version, environment: environment_label, rails_env: Rails.env }
  end

  # Một tag gộp cho log: "v1.0.1 Production".
  def log_tag
    "v#{version} #{environment_label}"
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/docker rspec spec/lib/system_info_spec.rb`
Expected: PASS (5 examples, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add config/initializers/version.rb lib/system_info.rb spec/lib/system_info_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): read app version into a constant and SystemInfo module

Read version.txt once at boot into ElectricWaterManagement::VERSION and
expose version + environment label through a stateless SystemInfo module
(single source of truth). Log a tagged startup line on boot.

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
      expect(response.media_type).to eq("application/json")
      body = JSON.parse(response.body)
      expect(body["version"]).to eq(ElectricWaterManagement::VERSION)
      expect(body["environment"]).to eq(SystemInfo.environment_label)
      expect(body["rails_env"]).to eq(Rails.env.to_s)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/version_spec.rb`
Expected: FAIL with `No route matches [GET] "/version"` (routing error).

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

GET /version returns {version, environment, rails_env} without
authentication so deploy automation and support can verify the running
release (including the offline Mini PC).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Tag logs with version + environment

**Files:**
- Modify: `config/environments/production.rb:38`

The log-tag *content* is already unit-tested via `SystemInfo.log_tag` (Task 1). This task wires that content into the production logger. The lambda is evaluated per-request at runtime, so the `VERSION` constant (defined in an initializer that runs after `production.rb`) and `SystemInfo` are available by then.

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

Run: `bin/docker bash -lc 'RAILS_ENV=production SECRET_KEY_BASE=dummy bin/rails runner "puts Rails.application.config.log_tags.first.call(nil)"'`
Expected output: `v<version> Production` (e.g. `v1.0.1 Production`).

If the production environment cannot boot inside the dev container (missing prod env vars), skip this command — `SystemInfo.log_tag` correctness is already covered by `spec/lib/system_info_spec.rb`, and this step is only wiring.

- [ ] **Step 3: Commit**

```bash
git add config/environments/production.rb
git commit -m "$(cat <<'EOF'
feat(version): tag production logs with version and environment

Prepend "v<version> <environment>" to every production log line (request
logs and error reports) so a bug reported from an offline Mini PC traces
to a release, and logs aggregated across the two Railway environments stay
distinguishable.

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
      expect(response.body).to include("v#{ElectricWaterManagement::VERSION}")
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "đáy sidebar"`
Expected: FAIL — body does not include the version string yet.

- [ ] **Step 3: Restructure the sidebar and add the version block**

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
  <div class="px-3 py-2 border-t border-gray-100 text-[11px] text-gray-400 leading-tight">
    <div>v<%= SystemInfo.version %></div>
    <div><%= SystemInfo.environment_label %></div>
  </div>
</aside>
```

Note: `overflow-y-auto` moved from `<aside>` onto `<nav>` (which is now `flex-1`) so the nav scrolls internally while the version block stays pinned at the bottom.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "đáy sidebar"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/_sidebar.html.erb spec/requests/version_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): show version and environment at the sidebar bottom

Pin a compact two-line block (version, then environment) to the bottom of
the sidebar so the running release is visible on every page after login —
key for telling the near-identical Railway environments apart.

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
      expect(response.body).to include("v#{ElectricWaterManagement::VERSION}")
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

with these two lines (subtitle margin tightened, version line added below — single line is fine here since the login card is not width-constrained):

```erb
  <p class="text-sm text-gray-600 mb-1">Hệ thống quản lý điện nội bộ Sư đoàn</p>
  <p class="text-xs text-gray-400 mb-6">v<%= SystemInfo.version %> · <%= SystemInfo.environment_label %></p>
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/version_spec.rb -e "màn hình đăng nhập"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/devise/sessions/new.html.erb spec/requests/version_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): show version and environment on the login screen

Add a muted version + environment line under the login subtitle so testers
can identify the release and environment before signing in.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Stamp the version into the Excel export

**Files:**
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
          expect(all_text).to include("v#{ElectricWaterManagement::VERSION}")
        end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "đóng dấu phiên bản"`
Expected: FAIL — the version string is not in the workbook yet.

- [ ] **Step 3: Add the version footer row**

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
    sheet.add_row ["Phiên bản hệ thống: v#{SystemInfo.version} · Môi trường: #{SystemInfo.environment_label}"],
                  style: [version_style]

    sheet.column_widths(*Array.new(total_columns, 14))
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "đóng dấu phiên bản"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/billing/show.xlsx.axlsx spec/requests/billing_spec.rb
git commit -m "$(cat <<'EOF'
feat(version): stamp version and environment into Excel export footer

Add a small footer row below the totals row of the billing workbook so an
exported report can be traced back to the release that produced it.

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

Navigate to the login page (`/users/sign_in`). Take a `preview_screenshot`. Confirm the version + environment line (`v<version> · <environment>`) appears under the subtitle.

- [ ] **Step 4: Verify the sidebar shows the version**

Sign in, then `preview_snapshot`/`preview_screenshot` of any page. Confirm the two-line version block (version, then environment) is pinned at the bottom of the sidebar.

- [ ] **Step 5: Verify the endpoint**

`preview_eval`: `await fetch('/version').then(r => r.json())`. Confirm it returns `{version, environment, rails_env}` with the expected version.

- [ ] **Step 6: Final commit (if any verification fixes were needed)**

Only if Steps 3–5 surfaced issues that required code changes; otherwise skip. Commit with an appropriate `fix(version): ...` message ending in the `Co-Authored-By` trailer.

---

## Self-Review notes (already reconciled against the spec)

- **Spec coverage:** version constant (Task 1) · `SystemInfo` single source (Task 1) · `/version` JSON public (Task 2) · log tag version+environment (Tasks 1+3) · sidebar two-line (Task 4) · login (Task 5) · Excel footer (Task 6) · English env label + `APP_ENVIRONMENT_LABEL` fallback (Task 1) · tests per surface (each task) · full suite (Task 7).
- **No admin "system info" page**, per the approved spec (dropped as YAGNI).
- **No new i18n keys:** the Excel template hardcodes Vietnamese (matching its existing style); the sidebar/login carry only `vX.Y.Z` + the English environment label.
- **Method names are consistent across tasks:** `SystemInfo.version`, `.environment_label`, `.to_h`, `.log_tag`; constant `ElectricWaterManagement::VERSION`.
- **Ops follow-up (P4):** set `APP_ENVIRONMENT_LABEL` (English) on each Railway environment and the Mini PC. Out of scope for this plan.
