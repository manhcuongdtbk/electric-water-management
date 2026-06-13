# Tự động hoá demo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the MVP of automated demo (spec [#343](https://github.com/manhcuongdtbk/electric-water-management/issues/343)): per-feature `spec/demo/` specs recorded to video via Playwright (scoped to demo specs only), with Vietnamese caption banners and interaction highlighting, surfaced on the PR for the owner and bundled at release for the customer, enforced by a CI guardrail.

**Architecture:** Demo specs are real Capybara specs in `spec/demo/` (type `:demo`), excluded from the normal `bundle exec rspec` run and executed by a dedicated CI job using the `capybara-playwright-driver` (native WebM video, no Xvfb/ffmpeg-capture). The existing ~1378-case suite stays on Selenium, untouched. A thin `DemoRecorder` DSL wraps Capybara to inject a caption banner + synthetic cursor/highlight (DOM elements, so they appear in the recorded video) and pace each step. Anti-drift: demo specs are green-to-merge like any spec.

**Tech Stack:** Rails 8, RSpec, Capybara, `capybara-playwright-driver` + Playwright (Node), Selenium (existing, untouched), `ffmpeg` (single WebM→MP4 transcode), GitHub Actions, bash guardrail (`.github/scripts/`).

**Phasing & de-risk:** Task 1 is a **walking skeleton** that proves the core unverified assumption (Playwright records a demo spec to video inside this project's Docker/CI). **Do not proceed past Task 1 until a `.webm` is produced.** If it cannot, stop and revisit ADR-038 (fallback: Cuprite+ffmpeg or Selenium+Xvfb) before building further.

**Conventions to follow (from AGENTS.md / existing code):**
- Code/identifiers/log English; UI/caption text Vietnamese; commits Conventional Commits, English, subject not starting with an uppercase token.
- Run `bin/docker rspec ...` after each change (not bare `rspec`).
- Demo specs live in `spec/demo/`; never add them to the default suite.
- Branch already exists: `feature/tu-dong-hoa-demo` (off `develop`). Commit per task.

---

## File Structure

**Create:**
- `spec/support/demo_recorder_config.rb` — registers the `:playwright_demo` Capybara driver + `before(:each, type: :demo)` hook + video-save wiring. (Auto-loaded by the `spec/support/**/*.rb` glob; harmless when no demo spec runs.)
- `spec/support/demo_recorder.rb` — the `DemoRecorder` class (the `demo.*` DSL: narrate/visit/click/fill/expect_text + caption banner + highlight + pacing).
- `spec/demo/smoke_demo_spec.rb` — walking-skeleton demo spec (Task 1), later a real template.
- `db/seeds/demo.rb` — curated demo dataset (Vietnamese, consistent "world").
- `lib/tasks/demo.rake` — `demo:seed` (load demo dataset) + `demo:record` (local convenience).
- `.github/scripts/check-demo-spec.sh` — guardrail: customer-facing label ⇒ demo spec required.
- `.github/demo-recorder/inject.js` — the JS injected for caption banner + synthetic cursor/highlight (kept as a file so it is reviewable and reusable).

**Modify:**
- `Gemfile` — add `capybara-playwright-driver` to the `:test` group.
- `package.json` (create if absent) — pin `playwright`.
- `spec/rails_helper.rb` — auto-tag `spec/demo/**` as `type: :demo` + exclude `:demo` from normal runs unless `DEMO=1`.
- `.github/workflows/ci.yml` — add `demo` job (record + transcode + upload + PR comment) and `demo-guardrail` job.
- `docs/THUAT_NGU.md` — add glossary terms (demo spec, recorder, caption banner, diễn hoạt thao tác).

---

## Task 1: Walking skeleton — prove Playwright records a demo spec to video

**Goal:** One trivial demo spec, driven by Playwright, produces a `.webm` locally in Docker. This de-risks ADR-038 before any further work.

**Files:**
- Modify: `Gemfile`
- Create: `package.json`
- Create: `spec/support/demo_recorder_config.rb`
- Modify: `spec/rails_helper.rb`
- Create: `spec/demo/smoke_demo_spec.rb`

- [ ] **Step 1: Add the driver gem to the test group**

In `Gemfile`, inside the existing `group :test do` block (where `capybara` and `selenium-webdriver` already live), add:

```ruby
  # Playwright-backed Capybara driver — used ONLY by spec/demo (type: :demo) to
  # record native WebM video. The main suite stays on Selenium. See ADR-038.
  gem "capybara-playwright-driver"
```

- [ ] **Step 2: Install gem + Playwright browser**

Run:
```bash
bin/docker bash -c "bundle install && npx --yes playwright install chromium"
```
Expected: bundler installs `capybara-playwright-driver` + `playwright-ruby-client`; Playwright downloads Chromium. (If `npx` is missing in the image, that is a real finding — note it; the CI job installs Node explicitly in Task 7.)

Create `package.json` so the Playwright version is pinned/repeatable:
```json
{
  "name": "electric-water-management-demo-tooling",
  "private": true,
  "devDependencies": {
    "playwright": "^1.49.0"
  }
}
```

- [ ] **Step 3: Register the `:playwright_demo` driver (video on)**

Create `spec/support/demo_recorder_config.rb`:
```ruby
# Capybara driver for demo specs (spec/demo, type: :demo) ONLY. Uses Playwright
# to record a native WebM per example. The main suite keeps :headless_chromium
# (Selenium) — see spec/support/system_test_config.rb and ADR-038.
require "capybara-playwright-driver"

# Directory where recorded videos are collected (gitignored; CI uploads them).
DEMO_VIDEO_DIR = Rails.root.join("tmp", "demo_videos").freeze

Capybara.register_driver :playwright_demo do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: true,
    record_video_dir: DEMO_VIDEO_DIR.to_s
  )
end

RSpec.configure do |config|
  config.before(:each, type: :demo) do
    FileUtils.mkdir_p(DEMO_VIDEO_DIR)
    driven_by :playwright_demo
  end

  # After each demo example, capture the saved video path and rename it to the
  # example's description so artifacts are human-identifiable.
  config.after(:each, type: :demo) do |example|
    Capybara.current_session.driver.on_save_screenrecord do |video_path|
      safe = example.full_description.parameterize
      FileUtils.mv(video_path, DEMO_VIDEO_DIR.join("#{safe}.webm"))
    end
  end
end
```
> Note: the exact `on_save_screenrecord` timing/placement may need adjustment against the installed gem version (the callback fires on session/context close). The executor verifies via Step 6 and adjusts if the file lands elsewhere.

- [ ] **Step 4: Isolate demo specs from the normal suite**

In `spec/rails_helper.rb`, inside the `RSpec.configure do |config|` block, add:
```ruby
  # spec/demo/** are demo recordings, not part of the normal suite. Auto-tag them
  # type: :demo and exclude them from `bundle exec rspec` unless DEMO=1 (the CI
  # `demo` job sets DEMO=1 and targets spec/demo explicitly). See ADR-037/038.
  config.define_derived_metadata(file_path: %r{/spec/demo/}) do |metadata|
    metadata[:type] = :demo
  end
  config.filter_run_excluding(type: :demo) unless ENV["DEMO"] == "1"
```

- [ ] **Step 5: Write the smoke demo spec**

Create `spec/demo/smoke_demo_spec.rb`:
```ruby
require "rails_helper"

# Walking skeleton: proves Playwright records a video. Replaced by real feature
# demos later; kept as the minimal smoke recording.
RSpec.describe "Demo recording smoke", type: :demo do
  it "loads the sign-in page" do
    visit "/"
    expect(page).to have_content("Đăng nhập").or have_current_path(%r{sign_in|users})
  end
end
```

- [ ] **Step 6: Run it and confirm a video file appears**

Run:
```bash
bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb"
ls -la tmp/demo_videos/
```
Expected: spec passes AND `tmp/demo_videos/` contains a `*.webm` file. **This is the de-risk gate — if no video is produced, stop and revisit ADR-038.**

- [ ] **Step 7: Gitignore the video dir + commit**

Append to `.gitignore`:
```
/tmp/demo_videos/
```
Then:
```bash
git add Gemfile Gemfile.lock package.json spec/support/demo_recorder_config.rb spec/rails_helper.rb spec/demo/smoke_demo_spec.rb .gitignore
git commit -m "feat(demo): walking skeleton — record a demo spec to webm via Playwright"
```

---

## Task 2: Confirm the normal suite still skips demo specs

**Goal:** `bundle exec rspec` (no DEMO) must NOT run `spec/demo`, so the new stack never touches the main suite.

**Files:** none (verification + guard test).

- [ ] **Step 1: Run the normal suite filter check**

Run:
```bash
bin/docker bash -c "bundle exec rspec spec/demo --dry-run"
```
Expected: `0 examples` (excluded because `DEMO` is unset).

- [ ] **Step 2: Confirm DEMO=1 includes them**

Run:
```bash
bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo --dry-run"
```
Expected: `1 example` (the smoke spec).

- [ ] **Step 3: Commit (if any config tweak was needed)**

```bash
git commit -am "test(demo): verify demo specs excluded from the default suite" --allow-empty
```

---

## Task 2b: Provision Playwright permanently in `Dockerfile.dev` (Node + npm playwright)

**Goal:** The dev image currently has **no Node.js**. Task 1 proved Playwright video works but installed Playwright into the *running* container (impermanent — lost on rebuild; the committed smoke spec depends on a path that won't exist on a fresh image). Decision (owner): add Node.js + npm-managed Playwright to `Dockerfile.dev` so demo recording survives rebuilds and any dev can record locally.

**Files:**
- Modify: `Dockerfile.dev`
- Modify: `spec/support/demo_recorder_config.rb`
- (uses) `package.json`

- [ ] **Step 1: Add Node + Playwright to `Dockerfile.dev`**

Read `Dockerfile.dev` first (match its base distro/user). Add: install Node.js with the major version read from **`.node-version`** (single source shared with CI's `actions/setup-node` via `node-version-file`) — e.g. `COPY .node-version ./` then `setup_$(cat .node-version).x` from NodeSource; copy `package.json` (+ lockfile if present); run `npm install`; run `npx playwright install --with-deps chromium`. Place it so layer caching is sensible (copy package.json before bulk app copy). Keep the existing Chromium/chromedriver (Selenium suite still needs them).

- [ ] **Step 2: Drop the impermanent CLI-path default in the driver config**

In `spec/support/demo_recorder_config.rb`, remove the hard-coded `/usr/local/bin/playwright-driver` default. `capybara-playwright-driver` auto-detects `node_modules/.bin/playwright`. Keep an *optional* override:
```ruby
  driver_args = { browser_type: :chromium, headless: true, record_video_dir: DEMO_VIDEO_DIR.to_s }
  cli = ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"]
  driver_args[:playwright_cli_executable_path] = cli if cli.present?
  Capybara::Playwright::Driver.new(app, **driver_args)
```
Also keep the `Capybara.current_driver = :playwright_demo` + `config.include Capybara::DSL/RSpecMatchers, type: :demo` approach the implementer adopted (driven_by isn't available for `:demo`).

- [ ] **Step 3: Rebuild the image and re-verify permanence (the new gate)**

Run (rebuild, then record from the CLEAN image — no in-container hacks):
```bash
bin/docker build   # or the project's rebuild path; read bin/docker
bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb"
ls tmp/demo_videos/*.webm
```
Expected: a `.webm` is produced from the freshly built image. This is the permanence gate — if it only works with the running-container hack, it isn't done.
> Rebuild may be long-running; that's expected for this one task.

- [ ] **Step 4: Commit**

```bash
git add Dockerfile.dev spec/support/demo_recorder_config.rb
git commit -m "build(demo): provision Node + Playwright in the dev image"
```

> **CI reconciliation (applied in Task 7):** with `package.json` present, the CI `demo` job uses `npm ci` (or `npm install`) + `npx playwright install --with-deps chromium` instead of an ad-hoc install — same mechanism as the image.

---

## Task 3: Caption banner + the `DemoRecorder` DSL

**Goal:** A `demo.*` DSL where each step shows a Vietnamese caption banner (a DOM element, so it is captured in the video) and paces the action. Banner presence IS assertable via Capybara.

**Files:**
- Create: `.github/demo-recorder/inject.js`
- Create: `spec/support/demo_recorder.rb`
- Modify: `spec/demo/smoke_demo_spec.rb`

- [ ] **Step 1: Write the failing test (caption banner shows)**

Replace `spec/demo/smoke_demo_spec.rb` body:
```ruby
require "rails_helper"

RSpec.describe "Demo recording smoke", type: :demo do
  it "shows a caption banner on each step" do
    demo = DemoRecorder.new(self)
    demo.visit("/", caption: "Mở trang đăng nhập")
    expect(page).to have_css("#demo-caption", text: "Mở trang đăng nhập")
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb"`
Expected: FAIL — `uninitialized constant DemoRecorder`.

- [ ] **Step 3: Write the injected JS (banner)**

Create `.github/demo-recorder/inject.js`:
```javascript
// Injected into the page under test so the caption banner and (Task 4) the
// synthetic cursor/highlight are real DOM — Playwright video captures the
// rendering engine, not the OS, so anything visible must live in the DOM.
window.__demo = window.__demo || {};

window.__demo.ensureCaption = function () {
  let el = document.getElementById("demo-caption");
  if (!el) {
    el = document.createElement("div");
    el.id = "demo-caption";
    el.style.cssText = [
      "position:fixed", "left:0", "right:0", "bottom:0", "z-index:2147483647",
      "padding:16px 24px", "font:600 20px/1.4 system-ui,sans-serif",
      "color:#fff", "background:rgba(17,24,39,.92)", "text-align:center"
    ].join(";");
    document.body.appendChild(el);
  }
  return el;
};

window.__demo.caption = function (text) {
  window.__demo.ensureCaption().textContent = text;
};
```

- [ ] **Step 4: Write the `DemoRecorder` class (minimal: visit + caption)**

Create `spec/support/demo_recorder.rb`:
```ruby
# Thin wrapper over Capybara for demo specs. Each step injects a Vietnamese
# caption banner (DOM, captured by the video) and paces the action so a viewer
# can follow. See docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md.
class DemoRecorder
  INJECT_JS = File.read(Rails.root.join(".github", "demo-recorder", "inject.js")).freeze

  # Seconds to hold each caption so it is readable in the recording. Override
  # with DEMO_STEP_PAUSE for faster local iteration.
  STEP_PAUSE = Float(ENV.fetch("DEMO_STEP_PAUSE", "1.2"))

  def initialize(spec)
    @spec = spec # the RSpec example, for Capybara DSL (page, visit, ...)
  end

  def visit(path, caption:)
    page.visit(path)
    show_caption(caption)
  end

  private

  def page
    @spec.page
  end

  def show_caption(text)
    page.execute_script(INJECT_JS)
    page.execute_script("window.__demo.caption(arguments[0]);", text)
    sleep STEP_PAUSE
  end
end
```

- [ ] **Step 5: Run to verify it passes**

Run: `bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb"`
Expected: PASS.

- [ ] **Step 6: Eyeball the video (visual verification)**

Run: `bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb" && ls tmp/demo_videos/`
Open the produced `.webm`; confirm the caption banner is visible. (Visual fidelity — not unit-assertable; tune `STEP_PAUSE`/styles if needed.)

- [ ] **Step 7: Commit**

```bash
git add .github/demo-recorder/inject.js spec/support/demo_recorder.rb spec/demo/smoke_demo_spec.rb
git commit -m "feat(demo): caption banner and DemoRecorder.visit DSL"
```

---

## Task 4: Interaction DSL (click/fill) + synthetic cursor & highlight

**Goal:** `demo.click` / `demo.fill` highlight the target, move a synthetic cursor to it, ripple on click, highlight the input, pause, then perform the real action. Presence of cursor/highlight DOM is assertable; visual smoothness is verify-by-artifact.

**Files:**
- Modify: `.github/demo-recorder/inject.js`
- Modify: `spec/support/demo_recorder.rb`
- Modify: `spec/demo/smoke_demo_spec.rb`

- [ ] **Step 1: Write the failing test (cursor element + highlight class)**

Append to `spec/demo/smoke_demo_spec.rb` a second example:
```ruby
  it "highlights the element it acts on" do
    demo = DemoRecorder.new(self)
    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo", caption: "Nhập tên đăng nhập")
    expect(page).to have_css("#demo-cursor")
  end
```
> If the sign-in field label differs, adjust the locator after reading `app/views/devise/sessions/new.html.erb`.

- [ ] **Step 2: Run to verify it fails**

Run: `bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb -e highlights"`
Expected: FAIL — `NoMethodError: fill` (or no `#demo-cursor`).

- [ ] **Step 3: Add cursor + highlight to the injected JS**

Append to `.github/demo-recorder/inject.js`:
```javascript
window.__demo.ensureCursor = function () {
  let c = document.getElementById("demo-cursor");
  if (!c) {
    c = document.createElement("div");
    c.id = "demo-cursor";
    c.style.cssText = [
      "position:fixed", "width:22px", "height:22px", "z-index:2147483647",
      "margin:-11px 0 0 -11px", "border-radius:50%",
      "background:rgba(37,99,235,.45)", "border:2px solid #2563eb",
      "transition:left .4s ease,top .4s ease", "pointer-events:none",
      "left:-100px", "top:-100px"
    ].join(";");
    document.body.appendChild(c);
  }
  return c;
};

// Move the cursor over an element's center and add a highlight outline.
window.__demo.point = function (selector) {
  const el = document.querySelector(selector);
  if (!el) return false;
  el.scrollIntoView({ block: "center", behavior: "instant" });
  const r = el.getBoundingClientRect();
  const c = window.__demo.ensureCursor();
  c.style.left = (r.left + r.width / 2) + "px";
  c.style.top = (r.top + r.height / 2) + "px";
  el.style.outline = "3px solid #2563eb";
  el.style.outlineOffset = "2px";
  el.dataset.demoHighlighted = "1";
  return true;
};

window.__demo.unpoint = function () {
  document.querySelectorAll("[data-demo-highlighted]").forEach((el) => {
    el.style.outline = ""; el.style.outlineOffset = ""; delete el.dataset.demoHighlighted;
  });
};

// A ripple at the cursor position to signal a click.
window.__demo.ripple = function () {
  const c = window.__demo.ensureCursor();
  const ring = document.createElement("div");
  ring.style.cssText = [
    "position:fixed", "z-index:2147483646", "width:22px", "height:22px",
    "margin:-11px 0 0 -11px", "border-radius:50%", "border:2px solid #2563eb",
    "left:" + c.style.left, "top:" + c.style.top,
    "animation:demo-ripple .5s ease-out forwards", "pointer-events:none"
  ].join(";");
  if (!document.getElementById("demo-ripple-kf")) {
    const s = document.createElement("style");
    s.id = "demo-ripple-kf";
    s.textContent = "@keyframes demo-ripple{to{transform:scale(2.6);opacity:0}}";
    document.head.appendChild(s);
  }
  document.body.appendChild(ring);
  setTimeout(() => ring.remove(), 600);
};
```

- [ ] **Step 4: Add `click`/`fill` to `DemoRecorder`**

In `spec/support/demo_recorder.rb`, add public methods (and a private helper to resolve a CSS selector for the synthetic cursor):
```ruby
  def click(locator, caption:)
    show_caption(caption)
    el = page.find_link_or_button(locator) # Capybara resolves text/value/id
    point_and_pause(el)
    page.execute_script("window.__demo.ripple();")
    el.click
    page.execute_script("window.__demo.unpoint();")
  end

  def fill(field, with:, caption:)
    show_caption(caption)
    el = page.find_field(field)
    point_and_pause(el)
    el.set(with)
    page.execute_script("window.__demo.unpoint();")
  end
```
and the private helper:
```ruby
  def point_and_pause(element)
    # Build a unique selector via the element's native id when present; else
    # fall back to scrolling Capybara already did + a generic highlight by xpath.
    selector = element[:id].present? ? "##{element[:id]}" : nil
    if selector
      page.execute_script("window.__demo.point(arguments[0]);", selector)
    end
    sleep STEP_PAUSE
  end
```
> `find_link_or_button` / `find_field` are Capybara built-ins. If an element lacks an `id`, the highlight is skipped but the action still runs (acceptable for MVP; refine selector strategy later).

- [ ] **Step 5: Run to verify it passes**

Run: `bin/docker bash -c "DEMO=1 bundle exec rspec spec/demo/smoke_demo_spec.rb"`
Expected: PASS (both examples).

- [ ] **Step 6: Eyeball the video**

Confirm cursor moves to the field, outline appears, caption updates. Tune timings/styles. (Visual — verify-by-artifact.)

- [ ] **Step 7: Commit**

```bash
git add .github/demo-recorder/inject.js spec/support/demo_recorder.rb spec/demo/smoke_demo_spec.rb
git commit -m "feat(demo): synthetic cursor, highlight, ripple, and click/fill DSL"
```

---

## Task 5: Demo seed (curated, consistent data)

**Goal:** A version-controlled demo dataset so recordings look real and consistent.

**Files:**
- Create: `db/seeds/demo.rb`
- Create: `lib/tasks/demo.rake`
- Test: `spec/demo/smoke_demo_spec.rb` (use seeded data)

- [ ] **Step 1: Write the demo seed**

Create `db/seeds/demo.rb` (use real model/column names from AGENTS.md naming table; values Vietnamese, decimals as BigDecimal). Minimal coherent world: one zone, two units, an open period 06/2026, a couple of contact points + meters with readings. Example skeleton (fill with the project's real required attributes — read the models first):
```ruby
# Curated demo dataset (separate from db/seeds.rb). Loaded by `rake demo:seed`
# and inside demo specs. Idempotent: clears prior demo data first.
ActiveRecord::Base.transaction do
  zone = Zone.create!(name: "Khu vực Trung tâm")
  unit = Unit.create!(name: "Đơn vị 1", zone: zone)
  # ... contact points, meters, an open Period 06/2026, sample readings ...
end
```
> Read `app/models/{zone,unit,period,meter,contact_point}.rb` for required validations before finalizing. Keep it small but realistic.

- [ ] **Step 2: Add the rake task**

Create `lib/tasks/demo.rake`:
```ruby
namespace :demo do
  desc "Load the curated demo dataset (db/seeds/demo.rb) into the current DB"
  task seed: :environment do
    load Rails.root.join("db", "seeds", "demo.rb")
  end
end
```

- [ ] **Step 3: Run the seed in a clean test DB**

Run:
```bash
bin/docker bash -c "RAILS_ENV=test bin/rails db:reset && RAILS_ENV=test bin/rails demo:seed"
```
Expected: completes without validation errors; verify counts in console.

- [ ] **Step 4: Point the smoke spec at seeded data**

Update a demo example to navigate to a page that shows the seeded zone/unit, asserting the Vietnamese data renders (e.g., `expect(page).to have_content("Khu vực Trung tâm")`).

- [ ] **Step 5: Commit**

```bash
git add db/seeds/demo.rb lib/tasks/demo.rake spec/demo/smoke_demo_spec.rb
git commit -m "feat(demo): curated demo seed and demo:seed rake task"
```

---

## Task 6: WebM→MP4 transcode helper

**Goal:** Convert recorded `.webm` to `.mp4` (H.264) for customer-channel compatibility (Zalo/PowerPoint/older players).

**Files:**
- Modify: `lib/tasks/demo.rake`

- [ ] **Step 1: Add a transcode task**

Append to `lib/tasks/demo.rake`:
```ruby
namespace :demo do
  desc "Transcode every tmp/demo_videos/*.webm to .mp4 (H.264) via ffmpeg"
  task :transcode do
    dir = Rails.root.join("tmp", "demo_videos")
    Dir[dir.join("*.webm")].each do |webm|
      mp4 = webm.sub(/\.webm\z/, ".mp4")
      system("ffmpeg", "-y", "-i", webm, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4) ||
        abort("ffmpeg failed for #{webm}")
    end
  end
end
```

- [ ] **Step 2: Verify locally (ffmpeg present in image?)**

Run:
```bash
bin/docker bash -c "command -v ffmpeg && DEMO=1 bundle exec rspec spec/demo && bin/rails demo:transcode && ls tmp/demo_videos/*.mp4"
```
Expected: `.mp4` files produced. If `ffmpeg` is missing in the dev image, note it; the CI job (Task 7) installs ffmpeg via apt. (Document the image gap as a follow-up if local dev needs it.)

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/demo.rake
git commit -m "feat(demo): ffmpeg webm->mp4 transcode rake task"
```

---

## Task 7: CI `demo` job (record + transcode + upload + PR comment)

**Goal:** A dedicated CI job records demo videos, transcodes, uploads artifacts, and posts a PR comment with links so the owner reviews on the PR.

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add the `demo` job**

Add to `.github/workflows/ci.yml` under `jobs:` (sibling of `tests`; gated on `changes` like `tests`). Mirror the `tests` job's Postgres service + env, then add Node/Playwright/ffmpeg:
```yaml
  demo:
    name: Demo recordings (Playwright)
    runs-on: ubuntu-latest
    needs: changes
    if: ${{ needs.changes.outputs.code_touched == 'true' }}
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U postgres" --health-interval 10s
          --health-timeout 5s --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_HOST: localhost
      DATABASE_PORT: 5432
      DATABASE_USERNAME: postgres
      ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD: postgres
      DEMO: "1"
    steps:
      - uses: actions/checkout@v6
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - uses: actions/setup-node@v6
        with:
          node-version-file: .node-version # single source shared with Dockerfile.dev
      - name: Install Playwright Chromium + ffmpeg
        run: |
          npx --yes playwright install --with-deps chromium
          sudo apt-get update && sudo apt-get install -y ffmpeg
      - name: Prepare DB + demo seed
        run: |
          bin/rails db:create db:schema:load
          bin/rails demo:seed
      - name: Record demo specs
        run: bundle exec rspec spec/demo
      - name: Transcode to mp4
        run: bin/rails demo:transcode
      - name: Upload demo videos
        if: ${{ !cancelled() }}
        uses: actions/upload-artifact@v4
        with:
          name: demo-videos
          path: tmp/demo_videos/*.mp4
          if-no-files-found: warn
```

- [ ] **Step 2: Post a PR comment linking the artifact**

Add a final step to the `demo` job:
```yaml
      - name: Comment on the PR with the demo artifact link
        if: ${{ !cancelled() }}
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR: ${{ github.event.pull_request.number }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: bash .github/scripts/post-demo-comment.sh
```
Create `.github/scripts/post-demo-comment.sh`:
```bash
#!/usr/bin/env bash
# Post (or update) a single PR comment linking the demo-videos artifact so the
# owner can watch the walkthrough without leaving the PR review. Idempotent via a
# marker line. FAIL-LOUD on gh errors.
set -uo pipefail

MARKER="<!-- demo-recordings -->"
body="$MARKER
🎬 **Demo walkthrough** cho pull request này đã được ghi hình.
Tải video (mp4) ở mục **Artifacts → demo-videos** của [lần chạy CI]($RUN_URL).
> Chặng owner: xem để xác nhận tính năng ổn trước khi merge."

# Find an existing marker comment and update it; else create one.
existing="$(gh pr view "$PR" --json comments \
  --jq ".comments[] | select(.body | contains(\"$MARKER\")) | .url" | head -1)"
if [[ -n "$existing" ]]; then
  gh api -X PATCH "$(echo "$existing" | sed 's#/pull/[0-9]*#&#')" >/dev/null 2>&1 || true
fi
gh pr comment "$PR" --body "$body" || { echo "✗ post-demo-comment: gh failed"; exit 1; }
```
> Inline still images on the PR are deferred (spec §5, "quyết ở plan"): the MVP links the artifact. The exact "update vs new comment" mechanics may be simplified to always-create if `gh` comment-editing proves awkward — keep one marker comment.

- [ ] **Step 3: Verify YAML locally**

Run: `bin/docker bash -c "ruby -ryaml -e 'YAML.load_file(%q(.github/workflows/ci.yml)); puts %q(ok)'"`
Expected: `ok` (no parse error).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/scripts/post-demo-comment.sh
chmod +x .github/scripts/post-demo-comment.sh
git commit -m "ci(demo): record/transcode/upload demo videos and comment on PR"
```
> Full verification of this job happens when the PR is pushed (Task 10) — CI is the only place the job actually runs.

---

## Task 8: Guardrail — customer-facing PRs must include a demo spec

**Goal:** A PR labelled customer-facing that does not add/modify `spec/demo/**` fails CI (ADR-040).

**Files:**
- Create: `.github/scripts/check-demo-spec.sh`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the guardrail script**

Create `.github/scripts/check-demo-spec.sh` (matches the existing bash guardrail style — fail-loud, English output):
```bash
#!/usr/bin/env bash
# Guardrail (ADR-040): a pull request labelled customer-facing MUST add or modify
# a demo spec (spec/demo/**). Internal PRs (no label) are exempt. FAIL-LOUD.
# Inputs via env: LABELS_JSON (pull_request.labels as JSON), BASE_SHA, HEAD_SHA.
set -uo pipefail

LABEL="customer-facing"

has_label="$(printf '%s' "${LABELS_JSON:-[]}" | grep -o "\"name\": *\"$LABEL\"" || true)"
if [[ -z "$has_label" ]]; then
  echo "✓ check-demo-spec: pull request not labelled '$LABEL' — demo spec not required."
  exit 0
fi

changed="$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" -- 'spec/demo/' || true)"
if [[ -n "$changed" ]]; then
  echo "✓ check-demo-spec: '$LABEL' pull request touches spec/demo — OK."
  exit 0
fi

echo "✗ check-demo-spec: pull request is labelled '$LABEL' but does not add/modify any spec/demo/** file."
echo "  Customer-facing changes must ship a demo spec (ADR-040). Add one under spec/demo/."
exit 1
```

- [ ] **Step 2: Add the guardrail job (always-on, like other guardrails)**

Add to `.github/workflows/ci.yml`:
```yaml
  demo-guardrail:
    name: Demo guardrail (customer-facing PR needs a demo spec)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - name: Require a demo spec for customer-facing pull requests (ADR-040)
        env:
          LABELS_JSON: ${{ toJSON(github.event.pull_request.labels) }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: bash .github/scripts/check-demo-spec.sh
```

- [ ] **Step 3: Test the script both ways locally**

Run (no label → pass):
```bash
LABELS_JSON='[]' BASE_SHA=HEAD~1 HEAD_SHA=HEAD bash .github/scripts/check-demo-spec.sh
```
Expected: `✓ ... not labelled`.

Run (labelled, no demo change → fail):
```bash
LABELS_JSON='[{"name":"customer-facing"}]' BASE_SHA=HEAD HEAD_SHA=HEAD bash .github/scripts/check-demo-spec.sh; echo "exit=$?"
```
Expected: `✗ ...` and `exit=1`.

- [ ] **Step 4: Create the label in the repo**

Run:
```bash
gh label create customer-facing --description "Khách sẽ thấy thay đổi này → bắt buộc có demo spec (ADR-040)" --color 0e8a16
```
Expected: label created (or "already exists").

- [ ] **Step 5: Commit**

```bash
chmod +x .github/scripts/check-demo-spec.sh
git add .github/scripts/check-demo-spec.sh .github/workflows/ci.yml
git commit -m "ci(demo): guardrail requiring a demo spec for customer-facing pull requests"
```

---

## Task 9: Glossary + spec status

**Goal:** Record the new terms in the single glossary source and mark the spec implemented.

**Files:**
- Modify: `docs/THUAT_NGU.md`
- Modify: `docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md`

- [ ] **Step 1: Add glossary entries**

In `docs/THUAT_NGU.md`, add (alphabetically/where the file groups terms): **demo spec**, **recorder (demo)**, **caption banner**, **diễn hoạt thao tác**, each one line, matching the file's existing format. Bump that file's version + changelog (ADR-002).

- [ ] **Step 2: Bump the design spec changelog (implemented)**

Add a changelog row to `docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md` (e.g. `0.2.0 — Hiện thực MVP (xem plan ...)`) and bump `version`.

- [ ] **Step 3: Commit**

```bash
git add docs/THUAT_NGU.md docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md
git commit -m "docs(demo): add glossary terms and mark demo automation spec implemented"
```

---

## Task 10: Push, open PR, monitor CI

**Goal:** Get the feature in front of CI (the only place the `demo` job actually runs) and open the PR to `develop`.

- [ ] **Step 1: Confirm the branch is current with develop**

Run: `git fetch origin develop && git log --oneline origin/develop -1` — if behind, integrate before pushing (per project rule).

- [ ] **Step 2: Push**

Run: `git push -u origin feature/tu-dong-hoa-demo`

- [ ] **Step 3: Open the PR to develop**

Run:
```bash
gh pr create --base develop --title "feat(demo): automated demo recording MVP" \
  --body "Implements the demo automation MVP. Refs #343."
```

- [ ] **Step 4: Monitor CI and report**

Watch the run; confirm `demo` job records + uploads, `demo-guardrail` passes, and the existing suite (Selenium) is unaffected. Fix failures, then report pass/fail (do not leave CI unverified).

---

## Self-Review

**Spec coverage (each spec section → task):**
- ADR-036 (one artifact, two stages): Tasks 3–4 (artifact), 7 (owner PR comment), 7+release (customer) — release-bundling is manual at MVP (owner downloads artifact + forwards per ADR-041); no automation task needed.
- ADR-037 (demo = green-to-merge spec + NV anchor): Tasks 1–5 (specs run in CI); NV anchors are per-feature spec metadata, added when real feature demos are written (template shown in spec §1).
- ADR-038 (Playwright scoped to spec/demo, Selenium kept, highlight via DOM): Tasks 1, 3, 4; Task 2 proves isolation.
- ADR-039 (MVP screencast + caption, TTS later): Tasks 3–4 (caption + screencast); TTS is Non-Goal.
- ADR-040 (guardrail): Task 8.
- ADR-041 (per-feature clips, render in CI from seed, owner gate + forward): Tasks 5 (seed), 7 (render in CI, artifacts), delivery is manual (no task).
- Recorder/seed/CI/surfacing components: Tasks 3/4, 5, 7, 7.

**Known gaps / deferred (intentional):** inline PR thumbnails (Task 7 note); release-bundle automation (manual at MVP per ADR-041); NV anchors materialise with the first real feature demo, not the smoke spec.

**Placeholder scan:** Task 5 seed body and Task 4 locator depend on reading the project's real models/views — flagged inline with the exact files to read, not left as blind "TODO". No fabricated assertions for visual fidelity (verify-by-artifact steps are explicit).

**Type consistency:** `DemoRecorder` API (`visit`/`click`/`fill` with `caption:`; `STEP_PAUSE`; `window.__demo.{caption,point,unpoint,ripple,ensureCaption,ensureCursor}`) is consistent across Tasks 3, 4. Driver name `:playwright_demo`, video dir `tmp/demo_videos`, `DEMO=1` gate, label `customer-facing` consistent across Tasks 1, 7, 8.
