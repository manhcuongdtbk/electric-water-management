# Role-Behavior Coverage Guardrail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Machine-enforce detailed per-role BEHAVIOR coverage (data scoping, zone/unit column visibility, commander read-only, zone-manager variant) on every page, the way #359 machine-enforced access coverage — so "access green" can no longer hide untested non-SA behavior.

**Architecture:** A data-driven matrix (`RoleBehaviorMatrix`) declares, for each page already in `RoleAccessMatrix::PAGES`, whether each of 4 behavior dimensions `applies(scenario)` or is `na(reason)`. Per-page setup lives in named methods (`RoleBehaviorScenarios`). Four **request-type** shared examples assert the behavior; each carries an anti-vacuous **precondition** (SA sees both records / control role has enabled inputs / SA sees the columns) so "fake coverage" fails instead of passing silently. A generated spec (`spec/requests/role_behavior_matrix_spec.rb`) wires matrix→shared-examples and asserts completeness; pure functions are unit-tested in `spec/lib/role_behavior_matrix_spec.rb`.

**Tech Stack:** RSpec request specs, Nokogiri (`Nokogiri::HTML(response.body)`), Devise `sign_in`, FactoryBot, existing `spec/support/sample_data.rb`, CanCanCan abilities. Read the design spec first: [docs/superpowers/specs/2026-06-14-role-behavior-coverage-design.md](../specs/2026-06-14-role-behavior-coverage-design.md) (ADR-058).

**Run tests with:** `bin/docker rspec <path>` (NEVER `bundle exec rspec` directly — wrong RAILS_ENV). All paths below are relative to the worktree root.

---

## Design facts (gathered — use these verbatim)

**The 6 roles** (`RoleAccessMatrix::ROLES`): `sa, ua_zm, ua, cmd_zm, cmd, tech`. Build users (matching `spec/requests/role_access_matrix_spec.rb` convention) inside a zone with a manager-unit and an other-unit:

```ruby
# zone.update!(manager_unit_id: unit_manager.id)  → unit_manager "manages" the zone
:sa     => create(:user, :system_admin)
:ua_zm  => create(:user, :unit_admin, unit: unit_manager)
:ua     => create(:user, :unit_admin, unit: unit_other)
:cmd_zm => create(:user, :commander,  unit: unit_manager)
:cmd    => create(:user, :commander,  unit: unit_other)
:tech   => create(:user, :technician)
```

**The 4 dimensions** and where each `applies` (everything else is `na` with the reason given in Task 6):

| Dimension | Applies to | Anti-vacuous precondition |
|---|---|---|
| `data_scoping` | blocks, groups, contact_points, meter_entries, pump_entries, billing, history, unit_config, electricity_supply, pump_allocations | SA sees ALL records' text; texts are distinct |
| `zone_unit_columns` | blocks, groups, contact_points, billing, meter_entries (cols `["Khu vực","Đơn vị"]`); pump_entries (cols `["Khu vực"]`) | SA's `<thead>` contains every listed column |
| `commander_readonly` | meter_entries, pump_entries, unit_config, electricity_supply | the control unit_admin role has ≥1 enabled input in the same view |
| `zone_manager_variant` | contact_points, unit_config | UA-ZM sees the ZM marker text |

**Why some "obvious" pages are `na`:** dashboard renders a *different partial per role* (`_system_admin` vs unit partial) — not column show/hide, and not same-page scoping → `data_scoping`/`zone_unit_columns` na. blocks/groups/contact_points have **no inline inputs** and commanders (`:read` only) can't reach the new/edit forms → `commander_readonly` na. electricity_supply/pump_allocations show "Khu vực" to everyone with access (not SA-gated) and their UA-ZM-vs-UA difference is pure *access* (plain UA redirected, already enforced by #359) → `zone_unit_columns` na and `zone_manager_variant` na.

**Per-page selectors / text (verbatim from views):**

- **Index column gate** (blocks, groups, contact_points): `show_zone_unit = current_user.system_admin?`; SA-only `<th>` text `Đơn vị` and `Khu vực`. Record name rendered as `<td>…name…</td>`.
- **Entry column gate** (meter_entries, pump_entries): `@show_zone_unit` wraps `<th>Khu vực</th>` (+ `<th>Đơn vị</th>` in meter_entries only).
- **billing columns**: gated by `@show_zone_column` / `@show_unit_column` (`@zone.nil?`); headers `Khu vực` / `Đơn vị`.
- **commander disabled inputs** (request-level patterns already used):
  - meter_entries (`spec/requests/meter_entries_spec.rb:65-125`): `html.css("table input[type='number'], table input[type='text']")` each `["disabled"]` present; submit `html.css("input[name='commit']")` disabled.
  - unit_config (`spec/requests/unit_config_spec.rb:83-157`): `html.css("input[type='number'], select")` (skip `type=="hidden"`) each disabled; submit hidden → `html.css("input[name='commit']")` empty. Submit text `Lưu cấu hình`.
  - electricity_supply (`spec/requests/electricity_supply_spec.rb:40-82`): `html.css("input[type='number']")` each disabled; submit `input[name='commit']` disabled.
- **contact_points ZM marker**: type dropdown `html.css("select#type option").map{|o| o["value"]}` includes `"water_pump"` / `"non_establishment"` for ZM, not for plain UA.
- **unit_config ZM marker**: `response.body` includes `"thuộc khu vực"` for UA-ZM; absent for plain UA.
- **sample data** (`spec/support/sample_data.rb`): `setup_zone_one_full_sample` → struct with `.zone, .unit_a (zone manager), .unit_b (non-manager), .period`, contact-point display names like `"Ban Tác huấn"` (unit_a), `"Đại đội 1"` (unit_b). `setup_zone_two_full_sample(period:)` builds a second zone.

---

## File structure

- Create `spec/support/role_behavior_matrix.rb` — `RoleBehaviorMatrix`: `DIMENSIONS`, `BEHAVIORS`, pure functions `coverage_gaps` / `dimension_gaps` / `invalid_entries`.
- Create `spec/support/role_behavior_scenarios.rb` — `RoleBehaviorScenarios`: one builder method per applies-page, returns a uniform `Scenario` struct.
- Create `spec/support/shared_examples/requests/role_data_scoping.rb`
- Create `spec/support/shared_examples/requests/role_zone_unit_columns.rb`
- Create `spec/support/shared_examples/requests/role_commander_readonly.rb`
- Create `spec/support/shared_examples/requests/role_zone_manager_variant.rb`
- Create `spec/requests/role_behavior_matrix_spec.rb` — generated behavior tests + completeness block.
- Create `spec/lib/role_behavior_matrix_spec.rb` — unit tests proving the pure functions bite.
- Modify `AGENTS.md` — update the "#373 chưa ép bằng máy" note.

---

## Task 1: `RoleBehaviorMatrix` pure module + unit tests

**Files:**
- Create: `spec/support/role_behavior_matrix.rb`
- Test: `spec/lib/role_behavior_matrix_spec.rb`

- [ ] **Step 1: Write the module with DIMENSIONS, a starter BEHAVIORS, and pure functions**

`spec/support/role_behavior_matrix.rb`:

```ruby
# Single source of truth for the role × page × behavior-dimension matrix
# (guardrail #373, ADR-058). Sibling to RoleAccessMatrix (#359, access only).
#
# RoleAccessMatrix says WHO can open each page (200 vs redirect). This module
# says, for each page, which detailed per-role BEHAVIORS are tested:
#   - data_scoping        — non-SA sees only its unit/zone data
#   - zone_unit_columns   — SA sees Khu vực/Đơn vị columns, non-SA does not
#   - commander_readonly  — CMD/CMD-ZM: inputs disabled + Lưu hidden/disabled
#   - zone_manager_variant— UA-ZM/CMD-ZM behave differently once both are IN
#
# Each (page, dimension) is either { applies: {params} } or { na: "reason" }.
# The generated spec (spec/requests/role_behavior_matrix_spec.rb) runs the real
# assertions (in shared examples) for every `applies`, and asserts completeness:
# every access-matrix page declares all 4 dimensions, every `na` carries a
# reason, every `applies` names a scenario. Pure policy functions live here so
# the guardrail can be unit-tested with synthetic input (spec/lib/...).
module RoleBehaviorMatrix
  DIMENSIONS = %i[data_scoping zone_unit_columns commander_readonly zone_manager_variant].freeze

  # slug => { dimension => { applies: {scenario:, ...} } | { na: "reason" } }
  # slug uses the SAME vocabulary as RoleAccessMatrix::PAGES (single source).
  # Filled fully in Task 6; starts with one page so the functions have data.
  BEHAVIORS = {
    "blocks" => {
      data_scoping:         { applies: { scenario: :blocks } },
      zone_unit_columns:    { applies: { scenario: :blocks } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form new/edit; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "blocks không có hành vi riêng cho zone-manager — UA-ZM hành xử như UA." }
    }
  }.freeze

  module_function

  # Pages declared in the access matrix but missing from BEHAVIORS (forgot to
  # declare behavior for a new page), and stale BEHAVIORS entries with no
  # matching access page. access_slugs defaults to the real access matrix.
  def coverage_gaps(access_slugs = RoleAccessMatrix::PAGES.keys, behaviors = BEHAVIORS)
    declared = behaviors.keys
    { missing: (access_slugs - declared).sort, stale: (declared - access_slugs).sort }
  end

  # Pages whose entry does not declare all 4 dimensions.
  # Returns { slug => [missing_dimension, ...] } (empty when complete).
  def dimension_gaps(behaviors = BEHAVIORS)
    behaviors.each_with_object({}) do |(slug, dims), gaps|
      missing = DIMENSIONS - dims.keys
      gaps[slug] = missing unless missing.empty?
    end
  end

  # Entries that are malformed: neither a valid `applies` (Hash with :scenario)
  # nor a valid `na` (non-empty String reason). Returns { slug => [dimension] }.
  def invalid_entries(behaviors = BEHAVIORS)
    behaviors.each_with_object({}) do |(slug, dims), bad|
      dims.each do |dimension, entry|
        next if valid_applies?(entry) || valid_na?(entry)
        (bad[slug] ||= []) << dimension
      end
    end
  end

  def valid_applies?(entry)
    entry.is_a?(Hash) && entry.key?(:applies) &&
      entry[:applies].is_a?(Hash) && entry[:applies][:scenario].is_a?(Symbol)
  end

  def valid_na?(entry)
    entry.is_a?(Hash) && entry.key?(:na) &&
      entry[:na].is_a?(String) && !entry[:na].strip.empty?
  end
end
```

- [ ] **Step 2: Write the unit tests (synthetic input proves the functions bite)**

`spec/lib/role_behavior_matrix_spec.rb`:

```ruby
# Unit-test the guardrail's PURE policy functions with synthetic input — proves
# each gap detector actually bites, without touching DB/Rails (mirrors #359's
# spec/lib/role_access_matrix_spec.rb).
require "rails_helper"

RSpec.describe RoleBehaviorMatrix do
  describe ".coverage_gaps" do
    it "flags an access page with no behavior declaration (missing)" do
      gaps = described_class.coverage_gaps(%w[blocks newpage], { "blocks" => {} })
      expect(gaps[:missing]).to eq(%w[newpage])
      expect(gaps[:stale]).to be_empty
    end

    it "flags a behavior entry with no matching access page (stale)" do
      gaps = described_class.coverage_gaps(%w[blocks], { "blocks" => {}, "ghost" => {} })
      expect(gaps[:stale]).to eq(%w[ghost])
      expect(gaps[:missing]).to be_empty
    end
  end

  describe ".dimension_gaps" do
    it "flags a page missing one of the 4 dimensions" do
      partial = { "blocks" => { data_scoping: { na: "x" }, zone_unit_columns: { na: "x" },
                                commander_readonly: { na: "x" } } } # zone_manager_variant missing
      expect(described_class.dimension_gaps(partial)).to eq("blocks" => [:zone_manager_variant])
    end
  end

  describe ".invalid_entries" do
    it "flags an empty na reason" do
      bad = { "blocks" => { data_scoping: { na: "  " } } }
      expect(described_class.invalid_entries(bad)).to eq("blocks" => [:data_scoping])
    end

    it "flags an applies without a scenario symbol" do
      bad = { "blocks" => { data_scoping: { applies: {} } } }
      expect(described_class.invalid_entries(bad)).to eq("blocks" => [:data_scoping])
    end

    it "flags an entry that is neither applies nor na" do
      bad = { "blocks" => { data_scoping: { wat: 1 } } }
      expect(described_class.invalid_entries(bad)).to eq("blocks" => [:data_scoping])
    end

    it "accepts a well-formed applies and na" do
      ok = { "blocks" => { data_scoping: { applies: { scenario: :blocks } },
                           zone_unit_columns: { na: "reason" } } }
      expect(described_class.invalid_entries(ok)).to be_empty
    end
  end
end
```

- [ ] **Step 3: Run the unit tests — expect PASS**

Run: `bin/docker rspec spec/lib/role_behavior_matrix_spec.rb`
Expected: all examples PASS (pure functions, no DB).

- [ ] **Step 4: Commit**

```bash
git add spec/support/role_behavior_matrix.rb spec/lib/role_behavior_matrix_spec.rb
git commit -m "test(role-behavior): add RoleBehaviorMatrix pure policy module (Refs #373)"
```

---

## Task 2: `role_data_scoping` shared example + scenario struct (pilot: blocks)

**Files:**
- Create: `spec/support/role_behavior_scenarios.rb`
- Create: `spec/support/shared_examples/requests/role_data_scoping.rb`
- Create: `spec/requests/role_behavior_matrix_spec.rb`

The scenario builder owns all per-page setup and returns a uniform struct so the shared example stays generic:

```
Scenario = Struct.new(
  :path,        # String URL or Symbol path-helper name
  :sa_user,     # a system_admin User
  :all_texts,   # Array<String> every record string SA must see (precondition)
  :checks,      # Array<{ user:, sees:, hides: [..] }> per accessible non-SA role
  :columns,     # Array<String> SA-only column headers (zone_unit_columns)
  :commander,   # { commander_users: [..], control_user:, input_css:, submit_css:, submit_optional: } 
  :zm,          # { zm_user:, non_zm_user:, marker:, ... }
  keyword_init: true
)
```

- [ ] **Step 1: Write the scenario builder skeleton + the blocks scenario**

`spec/support/role_behavior_scenarios.rb`:

```ruby
# Per-page setup for the behavior guardrail (#373, ADR-058). The matrix
# (RoleBehaviorMatrix) is pure data; the divergent setup each page needs lives
# here as named methods, so `applies: { scenario: :blocks }` -> .blocks builds
# the world and returns a uniform Scenario struct the shared examples consume.
module RoleBehaviorScenarios
  Scenario = Struct.new(:path, :sa_user, :all_texts, :checks,
                        :columns, :commander, :zm, keyword_init: true)

  module_function

  # Non-SA roles that can OPEN the page per the access matrix (so are subject to
  # scoping / commander / column behavior). Derived from the single source.
  def accessible_non_sa_roles(slug)
    RoleAccessMatrix::PAGES.fetch(slug)[:expect]
      .select { |_role, outcome| outcome == :ok }.keys - %i[sa tech]
  end

  # A zone with a manager-unit and an other-unit, plus an open period.
  # Mirrors role_access_matrix_spec.rb's world.
  def base_world
    zone = FactoryBot.create(:zone, name: "KV-#{SecureRandom.hex(3)}")
    unit_manager = FactoryBot.create(:unit, zone: zone, name: "ĐV-QL-#{SecureRandom.hex(3)}")
    unit_other   = FactoryBot.create(:unit, zone: zone, name: "ĐV-Khac-#{SecureRandom.hex(3)}")
    zone.update!(manager_unit_id: unit_manager.id)
    FactoryBot.create(:period, closed: false)
    { zone: zone, unit_manager: unit_manager, unit_other: unit_other }
  end

  # role -> the unit that role belongs to in base_world.
  def unit_for(role, world)
    %i[ua_zm cmd_zm].include?(role) ? world[:unit_manager] : world[:unit_other]
  end

  def make_user(role, world)
    case role
    when :sa     then FactoryBot.create(:user, :system_admin)
    when :ua_zm, :ua  then FactoryBot.create(:user, :unit_admin, unit: unit_for(role, world))
    when :cmd_zm, :cmd then FactoryBot.create(:user, :commander, unit: unit_for(role, world))
    when :tech   then FactoryBot.create(:user, :technician)
    end
  end

  # --- blocks (pilot) -------------------------------------------------------
  def blocks
    w = base_world
    mgr = FactoryBot.create(:block, unit: w[:unit_manager], name: "Khối-QL-#{SecureRandom.hex(3)}")
    oth = FactoryBot.create(:block, unit: w[:unit_other],   name: "Khối-Khac-#{SecureRandom.hex(3)}")
    checks = accessible_non_sa_roles("blocks").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      foreign = owned == mgr.name ? oth.name : mgr.name
      { user: user, sees: owned, hides: [foreign] }
    end
    Scenario.new(path: blocks_path_string, sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: %w[Khu\ vực Đơn\ vị])
  end

  # Path helpers are not available in a plain module; resolve via Rails routes.
  def blocks_path_string = Rails.application.routes.url_helpers.blocks_path
end
```

NOTE on `columns:` strings: use real spaces, e.g. `["Khu vực", "Đơn vị"]`. Write them as a normal array literal `["Khu vực", "Đơn vị"]` in the actual file (the escaped form above is only to fit the table).

- [ ] **Step 2: Write the `role_data_scoping` shared example**

`spec/support/shared_examples/requests/role_data_scoping.rb`:

```ruby
# Request-type shared example: non-SA roles see ONLY their unit/zone's data.
# Anti-vacuous precondition: SA must render EVERY record string and the strings
# must be distinct — so a page with nothing to distinguish (or duplicate text)
# fails instead of passing silently. `scenario` is a RoleBehaviorScenarios::Scenario.
RSpec.shared_examples "role data scoping" do |scenario|
  it "các record test là chuỗi phân biệt (precondition)" do
    expect(scenario.all_texts.uniq.length).to eq(scenario.all_texts.length)
  end

  it "SA thấy mọi record (precondition — record thật, render thật)" do
    sign_in scenario.sa_user
    get scenario.path
    aggregate_failures do
      scenario.all_texts.each { |t| expect(response.body).to include(t) }
    end
  end

  scenario.checks.each_with_index do |check, idx|
    it "non-SA ##{idx} chỉ thấy data trong phạm vi của mình" do
      # foreign strings must be real (SA-rendered) so the absence is meaningful
      check[:hides].each { |h| expect(scenario.all_texts).to include(h) }

      sign_in check[:user]
      get scenario.path
      expect(response.body).to include(check[:sees])
      check[:hides].each { |h| expect(response.body).not_to include(h) }
    end
  end
end
```

- [ ] **Step 3: Write the generated spec wiring blocks→data_scoping**

`spec/requests/role_behavior_matrix_spec.rb`:

```ruby
# Generated per-role BEHAVIOR tests + completeness guardrail (#373, ADR-058).
# Sibling to role_access_matrix_spec.rb (#359, access). For every page in
# RoleBehaviorMatrix::BEHAVIORS and every dimension that `applies`, build the
# page's scenario and run the matching shared example (real assertions live
# there). The completeness block (added in Task 6) forces every access page to
# declare all 4 dimensions, every na to carry a reason, every applies a scenario.
require "rails_helper"

RSpec.describe "Role behavior matrix (#373)", type: :request do
  SHARED_EXAMPLE_FOR = {
    data_scoping:         "role data scoping",
    zone_unit_columns:    "role zone-unit column visibility",
    commander_readonly:   "role commander read-only",
    zone_manager_variant: "role zone-manager variant"
  }.freeze

  RoleBehaviorMatrix::BEHAVIORS.each do |slug, dims|
    describe slug do
      dims.each do |dimension, entry|
        next unless entry.key?(:applies)

        describe dimension do
          scenario = RoleBehaviorScenarios.public_send(entry[:applies][:scenario])
          include_examples SHARED_EXAMPLE_FOR.fetch(dimension), scenario
        end
      end
    end
  end
end
```

CAUTION: `RoleBehaviorScenarios.<scenario>` runs at spec *load* time (outside an example), so it must build DB records inside examples, not at load. Fix: have the scenario method return a **lazy** builder. Simplest: wrap the build in a `let`-friendly call. Use this pattern instead in the generated spec:

```ruby
        describe dimension do
          let(:scenario) { RoleBehaviorScenarios.public_send(entry[:applies][:scenario]) }
          include_examples SHARED_EXAMPLE_FOR.fetch(dimension)
        end
```

and change every shared example to take the scenario via `let` (reference `scenario` inside `it`, iterate checks with a known max). Since `checks` count varies, iterate inside ONE example rather than generating an example per check:

Replace the per-check loop in `role_data_scoping.rb` with a single example:

```ruby
RSpec.shared_examples "role data scoping" do
  it "data scoping: SA thấy tất cả; mỗi non-SA chỉ thấy phạm vi mình" do
    expect(scenario.all_texts.uniq.length).to eq(scenario.all_texts.length) # distinct

    sign_in scenario.sa_user
    get scenario.path
    scenario.all_texts.each { |t| expect(response.body).to include(t) }     # precondition

    scenario.checks.each do |check|
      check[:hides].each { |h| expect(scenario.all_texts).to include(h) }   # foreign is real
      sign_in check[:user]
      get scenario.path
      expect(response.body).to include(check[:sees])
      check[:hides].each { |h| expect(response.body).not_to include(h) }
    end
  end
end
```

Use this single-example form for ALL four shared examples (reference `scenario` from the `let`). This avoids load-time DB access entirely.

- [ ] **Step 4: Run the generated spec — expect PASS for blocks data_scoping**

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb`
Expected: PASS (`blocks` → `data_scoping` green; blocks `zone_unit_columns` applies but its shared example "role zone-unit column visibility" does not exist yet → it will error. To keep this step green, temporarily set blocks `zone_unit_columns` to `{ na: "pending Task 3" }` in BEHAVIORS, OR implement Task 3 before running the full file. Recommended: run only the data_scoping group: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb -e "data scoping"`.)

- [ ] **Step 5: Prove the precondition bites (anti-false-positive)**

Temporarily edit `RoleBehaviorScenarios.blocks` so both blocks share a name (`oth` name = `mgr` name). Run the data_scoping group.
Expected: FAIL on the distinct-strings precondition. Revert.

- [ ] **Step 6: Commit**

```bash
git add spec/support/role_behavior_scenarios.rb \
        spec/support/shared_examples/requests/role_data_scoping.rb \
        spec/requests/role_behavior_matrix_spec.rb
git commit -m "test(role-behavior): data-scoping shared example + blocks scenario (Refs #373)"
```

---

## Task 3: `role_zone_unit_columns` shared example (pilot: blocks)

**Files:**
- Create: `spec/support/shared_examples/requests/role_zone_unit_columns.rb`
- Modify: `spec/support/role_behavior_matrix.rb` (blocks `zone_unit_columns` → applies)

- [ ] **Step 1: Write the shared example**

`spec/support/shared_examples/requests/role_zone_unit_columns.rb`:

```ruby
# Request-type shared example: SA sees the Khu vực/Đơn vị columns in the table
# header; non-SA accessible roles do not. Anti-vacuous precondition: SA's
# <thead> must actually contain every declared column, so a page without those
# columns fails instead of passing. Columns come from scenario.columns.
RSpec.shared_examples "role zone-unit column visibility" do
  it "zone/unit columns: SA thấy; non-SA không thấy" do
    sign_in scenario.sa_user
    get scenario.path
    sa_head = Nokogiri::HTML(response.body).css("thead").text
    scenario.columns.each do |col|
      expect(sa_head).to include(col)   # precondition: column really exists for SA
    end

    RoleBehaviorScenarios.accessible_non_sa_roles_for(scenario).each do |user|
      sign_in user
      get scenario.path
      head = Nokogiri::HTML(response.body).css("thead").text
      scenario.columns.each do |col|
        expect(head).not_to include(col)
      end
    end
  end
end
```

This needs the non-SA users on the scenario. Add a `column_users` field to the struct and populate it in each scenario (the accessible non-SA users). Update the struct definition to include `:column_users` and add a helper:

In `role_behavior_scenarios.rb`, extend `Scenario` with `:column_users`, and in `.blocks` set `column_users: accessible_non_sa_roles("blocks").map { |r| make_user(r, w) }`. Replace the `RoleBehaviorScenarios.accessible_non_sa_roles_for(scenario)` call above with `scenario.column_users`.

Final shared-example loop line: `scenario.column_users.each do |user|`.

- [ ] **Step 2: Flip blocks `zone_unit_columns` to applies**

In `spec/support/role_behavior_matrix.rb`, blocks `zone_unit_columns: { applies: { scenario: :blocks } }` (already set in Task 1 starter — keep it).

- [ ] **Step 3: Run — expect PASS**

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb -e "zone-unit"`
Expected: PASS (SA sees `Khu vực`/`Đơn vị`; the unit_admin/commander roles do not).

- [ ] **Step 4: Prove precondition bites**

Temporarily set blocks `columns: ["Nonexistent Column"]`. Run.
Expected: FAIL on SA precondition (column not in thead). Revert.

- [ ] **Step 5: Commit**

```bash
git add spec/support/shared_examples/requests/role_zone_unit_columns.rb \
        spec/support/role_behavior_scenarios.rb spec/support/role_behavior_matrix.rb
git commit -m "test(role-behavior): zone/unit column-visibility shared example (Refs #373)"
```

---

## Task 4: `role_commander_readonly` shared example (pilot: meter_entries)

**Files:**
- Create: `spec/support/shared_examples/requests/role_commander_readonly.rb`
- Modify: `spec/support/role_behavior_scenarios.rb` (add `.meter_entries`)
- Modify: `spec/support/role_behavior_matrix.rb` (add `meter_entries` entry)

- [ ] **Step 1: Add the meter_entries scenario**

meter_entries needs real meter data; reuse `setup_zone_one_full_sample` (defines `sample.zone`, `sample.unit_a` = zone manager, `sample.unit_b`, `sample.period`, and contact points). Add to `RoleBehaviorScenarios`:

```ruby
  # --- meter_entries --------------------------------------------------------
  def meter_entries
    sample = setup_zone_one_full_sample
    path = Rails.application.routes.url_helpers.meter_entries_path
    accessible = accessible_non_sa_roles("meter_entries") # ua_zm, ua, cmd_zm, cmd
    commander_users = accessible.select { |r| %i[cmd_zm cmd].include?(r) }
                                .map { |r| commander_user_for(r, sample) }
    control_user = unit_admin_user_for(:ua, sample) # plain UA: enabled inputs
    Scenario.new(
      path: path, sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: ["Khu vực", "Đơn vị"], column_users: [],
      commander: { commander_users: commander_users, control_user: control_user,
                   input_css: "table input[type='number'], table input[type='text']",
                   submit_css: "input[name='commit']", submit_optional: false }
    )
  end

  def commander_user_for(role, sample)
    unit = role == :cmd_zm ? sample.unit_a : sample.unit_b
    FactoryBot.create(:user, :commander, unit: unit)
  end

  def unit_admin_user_for(role, sample)
    unit = role == :ua_zm ? sample.unit_a : sample.unit_b
    FactoryBot.create(:user, :unit_admin, unit: unit)
  end
```

(`setup_zone_one_full_sample` and FactoryBot are available because shared examples/scenarios run in the RSpec context via `include SampleData` — confirm `spec/support/sample_data.rb` is a module included into examples; if it's defined as plain top-level methods, call them through an including context. If `RoleBehaviorScenarios` cannot see `setup_zone_one_full_sample`, `include SampleData` into the module or move the sample call into a `let` in the spec. Verify during this task and adjust: simplest robust fix is `extend SampleData` in `RoleBehaviorScenarios` if `SampleData` is a module.)

- [ ] **Step 2: Write the shared example**

`spec/support/shared_examples/requests/role_commander_readonly.rb`:

```ruby
# Request-type shared example: commanders (CMD/CMD-ZM) see the data but every
# business input is disabled and the save button is hidden/disabled. Anti-vacuous
# precondition: the CONTROL unit_admin role must have >=1 ENABLED input in the
# same view — so a page that simply has no inputs (or disables for everyone)
# can't pass as "commander read-only". Config from scenario.commander.
RSpec.shared_examples "role commander read-only" do
  it "commander read-only: input disabled + Lưu ẩn/disabled; control role enabled" do
    cfg = scenario.commander

    # precondition: control unit_admin sees at least one ENABLED input
    sign_in cfg[:control_user]
    get scenario.path
    control_inputs = Nokogiri::HTML(response.body).css(cfg[:input_css])
                       .reject { |i| i["type"] == "hidden" }
    expect(control_inputs).not_to be_empty
    expect(control_inputs.any? { |i| i["disabled"].nil? }).to be(true),
      "control role should have at least one enabled input"

    cfg[:commander_users].each do |cmd_user|
      sign_in cmd_user
      get scenario.path
      html = Nokogiri::HTML(response.body)
      inputs = html.css(cfg[:input_css]).reject { |i| i["type"] == "hidden" }
      expect(inputs).not_to be_empty
      inputs.each do |i|
        expect(i["disabled"]).to be_present,
          "expected input '#{i['name']}' disabled for commander on #{scenario.path}"
      end
      submit = html.css(cfg[:submit_css])
      if submit.any?
        expect(submit.first["disabled"]).to be_present
      elsif !cfg[:submit_optional]
        # hidden submit is acceptable only when submit_optional; otherwise require disabled-or-absent
        expect(submit).to be_empty
      end
    end
  end
end
```

- [ ] **Step 3: Add meter_entries to BEHAVIORS**

In `spec/support/role_behavior_matrix.rb` add (full entry):

```ruby
    "meter_entries" => {
      data_scoping:         { na: "pending Task 6" },
      zone_unit_columns:    { na: "pending Task 6" },
      commander_readonly:   { applies: { scenario: :meter_entries } },
      zone_manager_variant: { na: "UA-ZM nhập liệu như UA — không có biến thể riêng." }
    },
```

(The two `pending` na's are flipped to applies in Task 6; they keep dimension_gaps quiet meanwhile. They are still valid na entries so nothing breaks.)

- [ ] **Step 4: Run — expect PASS**

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb -e "commander read-only"`
Expected: PASS.

- [ ] **Step 5: Prove precondition bites**

Temporarily set meter_entries `commander[:input_css]` to a selector matching nothing (e.g. `"input.nonexistent"`). Run.
Expected: FAIL (control role has no enabled input / inputs empty). Revert.

- [ ] **Step 6: Commit**

```bash
git add spec/support/shared_examples/requests/role_commander_readonly.rb \
        spec/support/role_behavior_scenarios.rb spec/support/role_behavior_matrix.rb
git commit -m "test(role-behavior): commander read-only shared example + meter_entries (Refs #373)"
```

---

## Task 5: `role_zone_manager_variant` shared example (pilot: contact_points)

**Files:**
- Create: `spec/support/shared_examples/requests/role_zone_manager_variant.rb`
- Modify: `spec/support/role_behavior_scenarios.rb` (add `.contact_points`)
- Modify: `spec/support/role_behavior_matrix.rb` (add `contact_points` entry)

- [ ] **Step 1: Add the contact_points scenario**

The ZM marker is the `water_pump`/`non_establishment` option in the type dropdown of the NEW form, visible to UA-ZM, not to plain UA. Use the `new_contact_point_path(type: "residential")` page.

```ruby
  # --- contact_points -------------------------------------------------------
  def contact_points
    w = base_world
    Scenario.new(
      path: Rails.application.routes.url_helpers.new_contact_point_path(type: "residential"),
      sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      zm: { zm_user: FactoryBot.create(:user, :unit_admin, unit: w[:unit_manager]),
            non_zm_user: FactoryBot.create(:user, :unit_admin, unit: w[:unit_other]),
            marker_css: "select#type option",
            marker_values: %w[water_pump non_establishment] }
    )
  end
```

- [ ] **Step 2: Write the shared example**

`spec/support/shared_examples/requests/role_zone_manager_variant.rb`:

```ruby
# Request-type shared example: UA-ZM (unit_admin managing a zone) sees a
# zone-manager-only marker that a plain UA (same page, also accessible) does not.
# This is BEHAVIOR difference once both are IN — access-only differences belong
# to #359 and are declared `na` here. Config from scenario.zm.
RSpec.shared_examples "role zone-manager variant" do
  it "zone-manager variant: UA-ZM thấy marker; UA không" do
    cfg = scenario.zm

    sign_in cfg[:zm_user]
    get scenario.path
    zm_values = Nokogiri::HTML(response.body).css(cfg[:marker_css])
                  .map { |o| o["value"] }.compact
    cfg[:marker_values].each do |v|
      expect(zm_values).to include(v)   # precondition: ZM really sees the marker
    end

    sign_in cfg[:non_zm_user]
    get scenario.path
    ua_values = Nokogiri::HTML(response.body).css(cfg[:marker_css])
                  .map { |o| o["value"] }.compact
    cfg[:marker_values].each do |v|
      expect(ua_values).not_to include(v)
    end
  end
end
```

- [ ] **Step 3: Add contact_points to BEHAVIORS**

```ruby
    "contact_points" => {
      data_scoping:         { na: "pending Task 6" },
      zone_unit_columns:    { na: "pending Task 6" },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form; index không có input nội dòng." },
      zone_manager_variant: { applies: { scenario: :contact_points } }
    },
```

- [ ] **Step 4: Run — expect PASS**

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb -e "zone-manager variant"`
Expected: PASS.

- [ ] **Step 5: Prove precondition bites**

Temporarily set contact_points `marker_values: ["residential"]` (a value BOTH roles see). Run.
Expected: FAIL on the non-ZM assertion (UA also sees `residential`). Revert.

- [ ] **Step 6: Commit**

```bash
git add spec/support/shared_examples/requests/role_zone_manager_variant.rb \
        spec/support/role_behavior_scenarios.rb spec/support/role_behavior_matrix.rb
git commit -m "test(role-behavior): zone-manager-variant shared example + contact_points (Refs #373)"
```

---

## Task 6: Full backfill — all 18 pages × 4 dimensions + completeness gate

**Files:**
- Modify: `spec/support/role_behavior_matrix.rb` (complete BEHAVIORS for all 18 pages)
- Modify: `spec/support/role_behavior_scenarios.rb` (add remaining scenarios)
- Modify: `spec/requests/role_behavior_matrix_spec.rb` (add completeness block)

This is the bulk. Work one page at a time; after each page, run `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb` and keep it green. The completeness block (Step last) turns the gate on.

### Step 1: Complete the BEHAVIORS hash

Replace `BEHAVIORS` with the full 18-page map. The `applies` scenarios are listed in Step 2; the `na` reasons are final copy:

```ruby
  BEHAVIORS = {
    "dashboard" => {
      data_scoping:         { na: "Dashboard render partial khác hẳn theo vai trò (_system_admin vs đơn vị), không phải bảng cùng-trang để scope; phủ ở dashboard_spec + access #359." },
      zone_unit_columns:    { na: "Cột theo partial-riêng-mỗi-vai-trò, không phải ẩn/hiện cột cùng bảng." },
      commander_readonly:   { na: "Trang chỉ xem — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem tổng hợp như UA — không có biến thể riêng." }
    },
    "billing" => {
      data_scoping:         { applies: { scenario: :billing } },
      zone_unit_columns:    { applies: { scenario: :billing } },
      commander_readonly:   { na: "Trang chỉ xem kết quả — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem bảng tính như UA — không có biến thể riêng." }
    },
    "history" => {
      data_scoping:         { applies: { scenario: :history } },
      zone_unit_columns:    { na: "History LUÔN hiện cả cột Khu vực + Đơn vị mọi vai trò (so sánh kỳ cần context đầy đủ) — không ẩn theo vai trò." },
      commander_readonly:   { na: "Trang chỉ xem — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem lịch sử như UA — không có biến thể riêng." }
    },
    "electricity_supply" => {
      data_scoping:         { applies: { scenario: :electricity_supply } },
      zone_unit_columns:    { na: "Cột Khu vực hiện cho mọi vai trò có quyền (UA-ZM/CMD-ZM), không gated theo SA." },
      commander_readonly:   { applies: { scenario: :electricity_supply } },
      zone_manager_variant: { na: "Khác biệt UA-ZM vs UA là thuần access (UA bị redirect) — đã ép ở #359." }
    },
    "meter_entries" => {
      data_scoping:         { applies: { scenario: :meter_entries } },
      zone_unit_columns:    { applies: { scenario: :meter_entries } },
      commander_readonly:   { applies: { scenario: :meter_entries } },
      zone_manager_variant: { na: "UA-ZM nhập liệu như UA — không có biến thể riêng." }
    },
    "pump_entries" => {
      data_scoping:         { applies: { scenario: :pump_entries } },
      zone_unit_columns:    { applies: { scenario: :pump_entries } },
      commander_readonly:   { applies: { scenario: :pump_entries } },
      zone_manager_variant: { na: "UA-ZM nhập liệu như UA — không có biến thể riêng." }
    },
    "contact_points" => {
      data_scoping:         { applies: { scenario: :contact_points_index } },
      zone_unit_columns:    { applies: { scenario: :contact_points_index } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form; index không có input nội dòng; nút Sửa/Thêm ẩn." },
      zone_manager_variant: { applies: { scenario: :contact_points } }
    },
    "blocks" => {
      data_scoping:         { applies: { scenario: :blocks } },
      zone_unit_columns:    { applies: { scenario: :blocks } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form new/edit; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "blocks không có hành vi riêng cho zone-manager — UA-ZM hành xử như UA." }
    },
    "groups" => {
      data_scoping:         { applies: { scenario: :groups } },
      zone_unit_columns:    { applies: { scenario: :groups } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "groups không có biến thể zone-manager — UA-ZM như UA." }
    },
    "unit_config" => {
      data_scoping:         { applies: { scenario: :unit_config } },
      zone_unit_columns:    { na: "Trang cấu hình một đơn vị, không có bảng cross-zone/unit để ẩn cột." },
      commander_readonly:   { applies: { scenario: :unit_config } },
      zone_manager_variant: { applies: { scenario: :unit_config } }
    },
    "zones" => {
      data_scoping:         { na: "Chỉ SA truy cập (access #359) — không có non-SA để scope." },
      zone_unit_columns:    { na: "Chỉ SA truy cập — không có non-SA để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Chỉ SA — không có biến thể ZM." }
    },
    "units" => {
      data_scoping:         { na: "Chỉ SA truy cập — không có non-SA để scope." },
      zone_unit_columns:    { na: "Chỉ SA truy cập — không có non-SA để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Chỉ SA — không có biến thể ZM." }
    },
    "pump_allocations" => {
      data_scoping:         { applies: { scenario: :pump_allocations } },
      zone_unit_columns:    { na: "Cột Khu vực hiện cho mọi vai trò có quyền (UA-ZM/CMD-ZM), không gated theo SA." },
      commander_readonly:   { na: "CMD-ZM xem danh sách read-only (nút Sửa/Xóa ẩn), không có input nội dòng; form không truy cập được." },
      zone_manager_variant: { na: "Khác biệt UA-ZM vs UA là thuần access (UA bị redirect) — đã ép ở #359." }
    },
    "pricing" => {
      data_scoping:         { na: "Chỉ SA truy cập — không có non-SA để scope." },
      zone_unit_columns:    { na: "Chỉ SA truy cập — không có non-SA để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Chỉ SA — không có biến thể ZM." }
    },
    "ranks" => {
      data_scoping:         { na: "Chỉ SA truy cập — không có non-SA để scope." },
      zone_unit_columns:    { na: "Chỉ SA truy cập — không có non-SA để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Chỉ SA — không có biến thể ZM." }
    },
    "users" => {
      data_scoping:         { na: "Quản trị tài khoản SA/TECH toàn cục — không scope theo đơn vị nghiệp vụ." },
      zone_unit_columns:    { na: "Bảng người dùng không có cột Khu vực/Đơn vị gated theo SA." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Không có biến thể ZM cho quản trị tài khoản." }
    },
    "audit_logs" => {
      data_scoping:         { na: "Nhật ký hệ thống SA/TECH toàn cục — không scope theo đơn vị nghiệp vụ." },
      zone_unit_columns:    { na: "Bảng nhật ký không có cột Khu vực/Đơn vị gated theo SA." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Không có biến thể ZM cho nhật ký." }
    },
    "backups" => {
      data_scoping:         { na: "Chỉ TECH truy cập — không scope dữ liệu nghiệp vụ." },
      zone_unit_columns:    { na: "Không có bảng dữ liệu nghiệp vụ với cột Khu vực/Đơn vị." },
      commander_readonly:   { na: "Chỉ TECH truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Không có biến thể ZM cho sao lưu." }
    }
  }.freeze
```

### Step 2: Add the remaining scenarios

Add these methods to `RoleBehaviorScenarios`. Each follows the same struct shape as the pilots. Build users with `make_user`/`unit_admin_user_for`/`commander_user_for`; build records per page.

**`groups`** — identical shape to `blocks`, factory `:group`, columns `["Khu vực", "Đơn vị"]`:

```ruby
  def groups
    w = base_world
    mgr = FactoryBot.create(:group, unit: w[:unit_manager], name: "Nhóm-QL-#{SecureRandom.hex(3)}")
    oth = FactoryBot.create(:group, unit: w[:unit_other],   name: "Nhóm-Khac-#{SecureRandom.hex(3)}")
    checks = accessible_non_sa_roles("groups").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      { user: user, sees: owned, hides: [owned == mgr.name ? oth.name : mgr.name] }
    end
    Scenario.new(path: Rails.application.routes.url_helpers.groups_path,
                 sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: accessible_non_sa_roles("groups").map { |r| make_user(r, w) })
  end
```

**`contact_points_index`** — index page (distinct from `contact_points` which is the new-form ZM scenario). Factory `:contact_point` (residential, needs `initial_personnel_counts`). Path `contact_points_path(type: "residential")`. columns `["Khu vực", "Đơn vị"]`:

```ruby
  def contact_points_index
    w = base_world
    rank = current_period_rank
    mgr = FactoryBot.create(:contact_point, :residential, unit: w[:unit_manager],
            name: "ĐM-QL-#{SecureRandom.hex(3)}", initial_personnel_counts: { rank.id => 1 })
    oth = FactoryBot.create(:contact_point, :residential, unit: w[:unit_other],
            name: "ĐM-Khac-#{SecureRandom.hex(3)}", initial_personnel_counts: { rank.id => 1 })
    path = Rails.application.routes.url_helpers.contact_points_path(type: "residential")
    checks = accessible_non_sa_roles("contact_points").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      { user: user, sees: owned, hides: [owned == mgr.name ? oth.name : mgr.name] }
    end
    Scenario.new(path: path, sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: accessible_non_sa_roles("contact_points").map { |r| make_user(r, w) })
  end

  # The open period's rank used for personnel counts (contact points require it).
  def current_period_rank
    period = Period.kept.order(:year, :month).last
    period.ranks.first || period.ranks.create!(name: "Hạ sĩ", quota: 1, position: 1)
  end
```

(Confirm `initial_personnel_counts` key type from `spec/factories/contact_points.rb` — the factory default uses `{ 0 => 1 }`; the blocks_spec at line 100-101 uses `period.ranks.create!(...).id => 1`. Use a real rank id as shown. Verify during implementation and adjust the personnel-count key/value to satisfy ContactPoint validation.)

**`billing`, `history`, `meter_entries` (data_scoping/columns), `pump_entries`, `electricity_supply`, `pump_allocations`, `unit_config`** — these need real period/calculation data; build on `setup_zone_one_full_sample` (+ `setup_zone_two_full_sample(period:)` for a foreign zone where scoping is zone-level). Use the contact-point display names the sample creates as own/foreign text. Concrete per-page spec:

| scenario | path | own/foreign text source | columns | scoped roles (from access matrix) |
|---|---|---|---|---|
| `billing` | `billing_path` | unit_a CP name (`"Ban Tác huấn"`) vs unit_b CP name (`"Đại đội 1"`) — from `setup_zone_one_full_sample` | `["Khu vực", "Đơn vị"]` | ua_zm, ua, cmd_zm, cmd |
| `history` | `history_path(mode: "compare", period_a:, period_b:)` — needs 2 periods | same as billing | (na — no columns dim) | ua_zm, ua, cmd_zm, cmd |
| `meter_entries` | `meter_entries_path` | own unit_a meter's CP name vs unit_b's | `["Khu vực", "Đơn vị"]` | ua_zm, ua, cmd_zm, cmd |
| `pump_entries` | `pump_entries_path` | own zone pump CP vs other zone's | `["Khu vực"]` | ua_zm, ua, cmd_zm, cmd |
| `electricity_supply` | `electricity_supply_path` | own zone main-meter name vs zone-two's | (na) | ua_zm, cmd_zm only |
| `pump_allocations` | `pump_allocations_path` | own zone allocation target vs zone-two's | (na) | ua_zm, cmd_zm only |
| `unit_config` | `unit_config_path` | own unit deduction CP vs other unit's; ZM marker `"thuộc khu vực"` | (na) | ua_zm, ua, cmd_zm, cmd |

For each, build the struct: `data_scoping` needs `path, sa_user, all_texts (both names), checks (per scoped role: sees own, hides foreign)`. For zone-scoped pages (electricity_supply, pump_allocations, pump_entries) the "own/foreign" split is by ZONE: build `setup_zone_one_full_sample` and `setup_zone_two_full_sample(period: sample.period)`; the ua_zm/cmd_zm of zone one see zone-one's record, not zone-two's. Since only ua_zm/cmd_zm can access, both map to the zone-one manager unit (`sample.unit_a`).

For `unit_config` add `commander` (CMD/CMD-ZM disabled; control UA) and `zm` (`zm_user` = sample.unit_a admin sees `"thuộc khu vực"`, `non_zm_user` = a unit_admin of a non-managing unit; `marker_css`/`marker_values` don't fit the option-value model — use a body-text marker instead). For text-marker ZM variant, generalize the zm shared example to support a `marker_text` mode:

In `role_zone_manager_variant.rb`, support either option-values or body text:

```ruby
    if cfg[:marker_values]
      # option-value mode (contact_points) — as written above
    else
      sign_in cfg[:zm_user]; get scenario.path
      expect(response.body).to include(cfg[:marker_text])      # precondition
      sign_in cfg[:non_zm_user]; get scenario.path
      expect(response.body).not_to include(cfg[:marker_text])
    end
```

unit_config zm config: `zm: { zm_user:, non_zm_user:, marker_text: "thuộc khu vực" }`.

commander/electricity_supply config mirrors meter_entries but `input_css: "input[type='number']"`, control role = ua_zm (only ZM can access; plain UA redirected), commander_users = [cmd_zm only]:

```ruby
  def electricity_supply
    sample = setup_zone_one_full_sample
    path = Rails.application.routes.url_helpers.electricity_supply_path
    Scenario.new(
      path: path, sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      commander: { commander_users: [FactoryBot.create(:user, :commander, unit: sample.unit_a)],
                   control_user: FactoryBot.create(:user, :unit_admin, unit: sample.unit_a),
                   input_css: "input[type='number']", submit_css: "input[name='commit']",
                   submit_optional: false }
    )
  end
```

unit_config commander config: `input_css: "input[type='number'], select"` (skip hidden), submit hidden when read-only so set `submit_optional: true` and the shared example's `submit_css: "input[name='commit']"` (empty for commander, present for control). Control = plain UA (can edit own unit). commander_users = CMD and CMD-ZM.

> Implementation note: the data_scoping scenarios that depend on calculated billing data (billing, history, meter_entries, pump_entries) must render the scoped record names in the response. Verify each renders the chosen own/foreign string by signing in SA first (the precondition will tell you if a name isn't rendered). If a page proves not to render a per-unit string suitable for scoping assertion, STOP and reconsider: either pick a different rendered string, or (last resort, with explicit reason) mark that page's `data_scoping` as `na` and note why — do NOT leave a vacuous applies.

### Step 3: Add the completeness block to the generated spec

Append inside `RSpec.describe "Role behavior matrix (#373)"`:

```ruby
  describe "completeness (guardrail #373)" do
    it "mọi trang access-matrix đều khai hành vi (không thiếu, không stale)" do
      gaps = RoleBehaviorMatrix.coverage_gaps
      expect(gaps[:missing]).to be_empty,
        "Trang access-matrix chưa khai hành vi: #{gaps[:missing].join(', ')}. " \
        "Thêm vào RoleBehaviorMatrix::BEHAVIORS (mỗi dimension applies hoặc na kèm lý do)."
      expect(gaps[:stale]).to be_empty,
        "Entry BEHAVIORS không có trang access tương ứng: #{gaps[:stale].join(', ')}."
    end

    it "mỗi trang khai đủ 4 dimension hành vi" do
      gaps = RoleBehaviorMatrix.dimension_gaps
      expect(gaps).to be_empty,
        "Trang thiếu dimension: #{gaps.map { |s, d| "#{s} (#{d.join(', ')})" }.join('; ')}."
    end

    it "mọi entry đúng hình thức (na có lý do, applies có scenario)" do
      bad = RoleBehaviorMatrix.invalid_entries
      expect(bad).to be_empty,
        "Entry sai hình thức: #{bad.map { |s, d| "#{s} (#{d.join(', ')})" }.join('; ')}."
    end
  end
```

### Step 4: Run incrementally and finally the whole file

After each scenario added, run the whole behavior spec and keep it green:

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb`
Expected (final): ALL examples PASS, including the 3 completeness examples.

### Step 5: Commit

```bash
git add spec/support/role_behavior_matrix.rb spec/support/role_behavior_scenarios.rb \
        spec/requests/role_behavior_matrix_spec.rb \
        spec/support/shared_examples/requests/role_zone_manager_variant.rb
git commit -m "test(role-behavior): backfill all pages + completeness gate (Refs #373)"
```

---

## Task 7: Guardrail-bites verification + full suite + docs

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Prove the completeness gate bites (real, then revert)**

Temporarily change one page's `commander_readonly` from `applies`/`na` to `{ foo: 1 }`. Run:

Run: `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb -e "completeness"`
Expected: FAIL on `invalid_entries`. Revert.

Temporarily delete the whole `"backups"` entry. Run the same.
Expected: FAIL on `coverage_gaps` (missing: backups). Revert.

- [ ] **Step 2: Update the AGENTS.md note**

In `AGENTS.md`, find the role-coverage line (search `role-coverage`):

> (Hành vi chi tiết per-role — scoping/cột/commander-disable — chưa ép bằng máy: Issue #373.)

Replace with:

> Hành vi chi tiết per-role (scoping/cột/commander-disable/biến thể ZM) cũng **được máy ép** qua guardrail behavior-coverage (ADR-058): khai ở `spec/support/role_behavior_matrix.rb` (`RoleBehaviorMatrix::BEHAVIORS`, mỗi trang × 4 dimension = applies hoặc na kèm lý do), assertion thật trong `spec/support/shared_examples/requests/` với precondition chống-vacuous; thiếu khai/khai sai → `role_behavior_matrix_spec.rb` đỏ.

(AGENTS.md is a root meta file — NO version bump / changelog. Keep the change to that one parenthetical.)

- [ ] **Step 3: Run the full suite**

Run: `bin/docker rspec`
Expected: green (note any PRE-EXISTING flaky period/rank order-dependent failures per memory — if they appear, re-run those files in isolation to confirm they are unrelated to this change).

- [ ] **Step 4: Run doc-governance guardrails locally**

Run:
```bash
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status check-changelog-header check-adr-numbering; do bash .github/scripts/$s.sh; done
```
Expected: all ✓.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "docs: note role behavior coverage is now machine-enforced (Refs #373)"
```

---

## Task 8: Push, PR, CI

- [ ] **Step 1: Integrate latest develop, then push**

```bash
git fetch origin develop
git merge --no-edit origin/develop   # or rebase per project preference; resolve if needed
git push -u origin feature/373-role-behavior-coverage
```

- [ ] **Step 2: Open the PR (base develop, Closes #373)**

```bash
gh pr create --base develop --title "test(role-behavior): machine-enforce per-role behavior coverage (#373)" \
  --body "$(cat <<'EOF'
Closes #373.

Follows #359/ADR-056 (access coverage). Adds a data-driven guardrail that
machine-enforces detailed per-role BEHAVIOR coverage across all pages:
data scoping, zone/unit column visibility, commander read-only, zone-manager
variant. The anti-false-positive measure is per-dimension preconditions in
request-type shared examples (SA sees both records / control role has enabled
inputs / SA sees the columns), not assertion counting.

Spec + ADR-058: docs/superpowers/specs/2026-06-14-role-behavior-coverage-design.md

## Test plan
- [ ] `bin/docker rspec spec/lib/role_behavior_matrix_spec.rb` (pure functions bite)
- [ ] `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb` (behavior + completeness)
- [ ] Guardrail-bites manually verified (broke an entry → red → reverted)
- [ ] `bin/docker rspec` full suite green
- [ ] doc-governance guardrails green

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Watch CI in the background; report pass/fail**

```bash
gh pr checks --watch
```

---

## Self-review notes (for the implementer)

- **Load-time vs example-time:** scenarios build DB rows → call them inside a `let`, never at spec load. Every shared example references `scenario` from that `let`.
- **`SampleData` visibility:** if `RoleBehaviorScenarios` can't see `setup_zone_one_full_sample`, `extend SampleData` in the module (confirm `spec/support/sample_data.rb` defines a `SampleData` module; if it defines bare methods on the example group, move the sample call into the spec's `let` and pass the result into the scenario instead).
- **Path helpers in a plain module:** use `Rails.application.routes.url_helpers.<helper>`.
- **Worktree paths:** all edits/reads target the worktree tree (relative paths as written).
- **Honest na:** never leave a vacuous `applies`. If a page can't render a distinguishable per-scope string, mark `data_scoping` `na` with a concrete reason instead.
