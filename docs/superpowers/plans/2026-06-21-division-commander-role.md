# Division Commander Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 7th role "Chỉ huy Sư đoàn" (Division Commander, `division_commander`) — system-wide read-only access to all pages (like SA but cannot edit anything). Does not belong to any unit.

**Architecture:** New PostgreSQL enum value `division_commander` added to `user_role`. Authorization via CanCan `can :read` on all models (system-wide scope, no `:manage`/`:create`/`:update`/`:destroy`). A `User#system_wide_scope?` method returns true for both SA and DC, used across ~20 display/filter check points. Guardrail matrices expand from 6→7 roles.

**Tech Stack:** Rails 8, PostgreSQL enum, CanCan, RSpec, Hotwire/Stimulus

**Issue:** #315 item 2  
**Branch base:** develop (squash merge per Git Flow)  
**Test command:** `bin/docker rspec`

---

## File Structure

### New files
- `db/migrate/YYYYMMDDHHMMSS_add_division_commander_to_user_role.rb` — PostgreSQL ALTER TYPE
- `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` — Business confirmation doc (batch 2)

### Modified files (grouped by layer)

**Model layer:**
- `app/models/user.rb` — enum, validation, `clear_unit_for_non_unit_scoped_roles`, `system_wide_scope?`
- `app/models/ability.rb` — `division_commander_abilities` method + case branch

**Controller layer:**
- `app/controllers/concerns/business_role_required.rb` — add DC to ALLOWED_ROLES
- `app/controllers/concerns/settings_access_guard.rb` — update guards for DC
- `app/controllers/concerns/zone_unit_filterable.rb` — `system_admin?` → `system_wide_scope?` (4 methods)
- `app/controllers/concerns/meter_reading_entry.rb` — `system_wide_scope?`
- `app/controllers/concerns/freshness_indicatable.rb` — `system_wide_scope?`
- `app/controllers/users_controller.rb` — add DC to ROLES constant
- `app/controllers/billing_controller.rb` — `system_wide_scope?`
- `app/controllers/unit_config_controller.rb` — `system_wide_scope?` (6 checks)
- `app/controllers/contact_points_controller.rb` — `system_wide_scope?` (2 checks)
- `app/controllers/electricity_supply_controller.rb` — `system_wide_scope?`
- `app/services/dashboard_summary.rb` — handle `:division_commander` role

**View layer (system_admin? → system_wide_scope?):**
- `app/views/blocks/index.html.erb`
- `app/views/contact_points/index.html.erb`
- `app/views/groups/index.html.erb`
- `app/views/units/index.html.erb`
- `app/views/unit_config/show.html.erb`
- `app/views/pump_entries/show.html.erb`
- `app/views/users/index.html.erb`
- `app/views/meter_entries/show.html.erb`
- `app/views/pump_allocations/index.html.erb`
- `app/views/billing/show.html.erb`
- `app/views/dashboard/show.html.erb`
- `app/views/users/_form.html.erb`

**JavaScript:**
- `app/javascript/controllers/role_unit_toggle_controller.js` — add DC to NON_UNIT_SCOPED_ROLES

**i18n:**
- `config/locales/vi.yml` — role label

**Test infrastructure:**
- `spec/factories/users.rb` — `:division_commander` trait
- `spec/support/role_access_matrix.rb` — 6→7 roles, PAGES expectations
- `spec/support/role_behavior_matrix.rb` — DC behavior per page
- `spec/support/role_behavior_scenarios.rb` — `make_user` + scenario updates
- `spec/requests/role_access_matrix_spec.rb` — `build_user` for DC
- `spec/requests/freshness_roles_spec.rb` — DC test case
- `spec/requests/business_role_required_integration_spec.rb` — DC test case (if exists)
- `spec/abilities/ability_spec.rb` — DC ability assertions

**Documentation:**
- `docs/V2_HANH_VI_HE_THONG.md` — section 1 (6→7 roles) + changelog

---

## Task 1: Database + Model Foundation

**Files:**
- Create: `db/migrate/20260621120000_add_division_commander_to_user_role.rb`
- Modify: `app/models/user.rb`
- Modify: `spec/factories/users.rb`
- Modify: `config/locales/vi.yml`
- Modify: `app/javascript/controllers/role_unit_toggle_controller.js`

- [ ] **Step 1: Create migration**

```ruby
# db/migrate/20260621120000_add_division_commander_to_user_role.rb
class AddDivisionCommanderToUserRole < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TYPE user_role ADD VALUE 'division_commander'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "PostgreSQL does not support removing enum values"
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/docker bash -c "bin/rails db:migrate"`
Expected: Migration runs, `db/schema.rb` updates `create_enum "user_role"` to include `division_commander`.

- [ ] **Step 3: Update User model**

In `app/models/user.rb`:

Add `division_commander` to the enum:
```ruby
enum :role, {
  technician: "technician",
  system_admin: "system_admin",
  unit_admin: "unit_admin",
  commander: "commander",
  division_commander: "division_commander"
}
```

Add `system_wide_scope?` method (public, above `private`):
```ruby
def system_wide_scope?
  system_admin? || division_commander?
end
```

Update `clear_unit_for_non_unit_scoped_roles` to include DC:
```ruby
def clear_unit_for_non_unit_scoped_roles
  self.unit_id = nil if technician? || system_admin? || division_commander?
end
```

The `validates :unit_id, presence: true` check on line 20 (`if: -> { unit_admin? || commander? }`) does NOT need changing — DC is not in that list, so unit_id is optional (correct).

- [ ] **Step 4: Add factory trait**

In `spec/factories/users.rb`, add after the `:commander` trait:
```ruby
trait :division_commander do
  role { "division_commander" }
end
```

No `association :unit` — DC does not belong to a unit.

- [ ] **Step 5: Add i18n label**

In `config/locales/vi.yml` at line 62 (after `commander:` line), add:
```yaml
          division_commander: "Chỉ huy Sư đoàn"
```

- [ ] **Step 6: Update Stimulus controller**

In `app/javascript/controllers/role_unit_toggle_controller.js`, update:
```javascript
const NON_UNIT_SCOPED_ROLES = ["system_admin", "technician", "division_commander"]
```

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260621120000_add_division_commander_to_user_role.rb \
        db/schema.rb \
        app/models/user.rb \
        spec/factories/users.rb \
        config/locales/vi.yml \
        app/javascript/controllers/role_unit_toggle_controller.js
git commit -m "feat(role): add division_commander enum, model, factory, i18n"
```

---

## Task 2: Authorization — Ability + Guards

**Files:**
- Modify: `app/models/ability.rb`
- Modify: `app/controllers/concerns/business_role_required.rb`
- Modify: `app/controllers/concerns/settings_access_guard.rb`
- Modify: `app/controllers/users_controller.rb`
- Modify: `app/views/users/_form.html.erb`

- [ ] **Step 1: Add division_commander_abilities to Ability**

In `app/models/ability.rb`:

Add case branch in `initialize` (line 18, before `end`):
```ruby
when :division_commander then division_commander_abilities(user)
```

So the full case becomes:
```ruby
case user.role.to_sym
when :technician          then technician_abilities(user)
when :system_admin        then system_admin_abilities(user)
when :unit_admin          then unit_admin_abilities(user)
when :commander           then commander_abilities(user)
when :division_commander  then division_commander_abilities(user)
end
```

Add the method at the end of `private` section:
```ruby
def division_commander_abilities(_user)
  [Unit, ContactPoint, Meter, MainMeter, Block, Group,
   Period, Rank, PumpAllocation,
   MeterReading, MainMeterReading, PersonnelEntry,
   NonEstablishmentSnapshot, UnitConfig, OtherDeduction, Calculation
  ].each { |m| can :read, m }
  can :read, Zone, discarded_at: nil

  can :read, User
  can :read, PaperTrail::Version
end
```

Key differences from SA: only `:read` (no `:manage`, no `:recalculate`). Key differences from commander: system-wide scope (no `unit_id` conditions).

- [ ] **Step 2: Update BusinessRoleRequired**

In `app/controllers/concerns/business_role_required.rb`, line 7:
```ruby
ALLOWED_ROLES = %w[system_admin unit_admin commander division_commander].freeze
```

- [ ] **Step 3: Update SettingsAccessGuard**

In `app/controllers/concerns/settings_access_guard.rb`:

Update `require_system_admin!` (line 15-18) — DC can view all settings pages (read-only):
```ruby
def require_system_admin!
  return if current_user&.system_admin? || current_user&.division_commander?
  deny_settings_access
end
```

Update `require_system_admin_or_zone_manager!` (line 20-23) — DC can view pump_allocations:
```ruby
def require_system_admin_or_zone_manager!
  return if current_user&.system_admin? || current_user&.division_commander? || current_zone_manager?
  deny_settings_access
end
```

Update `require_account_manager!` (line 25-28) — DC can view users list (read-only):
```ruby
def require_account_manager!
  return if current_user&.system_admin? || current_user&.technician? || current_user&.division_commander?
  deny_settings_access
end
```

- [ ] **Step 4: Update UsersController ROLES constant**

In `app/controllers/users_controller.rb`, line 20:
```ruby
ROLES = %w[system_admin unit_admin commander division_commander technician].freeze
```

- [ ] **Step 5: Update user form role list**

In `app/views/users/_form.html.erb`, lines 1-5:
```erb
<% available_roles = if current_user.technician?
                       %w[technician system_admin unit_admin commander division_commander]
                     else
                       %w[system_admin unit_admin commander division_commander]
                     end %>
```

- [ ] **Step 6: Commit**

```bash
git add app/models/ability.rb \
        app/controllers/concerns/business_role_required.rb \
        app/controllers/concerns/settings_access_guard.rb \
        app/controllers/users_controller.rb \
        app/views/users/_form.html.erb
git commit -m "feat(role): add division_commander abilities and access guards"
```

---

## Task 3: Navigation + Display Logic

This task updates all `current_user.system_admin?` display/filter checks to `current_user.system_wide_scope?` so DC sees the SA-style UI (zone/unit filters, columns, dropdowns).

**Files:**
- Modify: `app/controllers/concerns/zone_unit_filterable.rb`
- Modify: `app/controllers/concerns/meter_reading_entry.rb`
- Modify: `app/controllers/concerns/freshness_indicatable.rb`
- Modify: `app/controllers/billing_controller.rb`
- Modify: `app/controllers/unit_config_controller.rb`
- Modify: `app/controllers/contact_points_controller.rb`
- Modify: `app/controllers/electricity_supply_controller.rb`
- Modify: `app/helpers/sidebar_helper.rb`
- Modify: `app/services/dashboard_summary.rb`
- Modify: 11 view files (listed below)

### Key pattern

Every `current_user.system_admin?` used for display/filter logic becomes `current_user.system_wide_scope?`. Exception: `dashboard/show.html.erb` line 6 (open period banner) stays as-is — DC is read-only, same as commander.

- [ ] **Step 1: Update ZoneUnitFilterable**

In `app/controllers/concerns/zone_unit_filterable.rb`, replace `current_user.system_admin?` with `current_user.system_wide_scope?` on lines 42, 59, 79, 125 (4 occurrences in `apply_sa_zone_unit_filter`, `apply_sa_zone_filter`, `apply_sa_zone_unit_filter_with_direct_zone`, `set_sa_available_filters_from`).

Example (line 42):
```ruby
# Before:
return scope unless current_user.system_admin?
# After:
return scope unless current_user.system_wide_scope?
```

Apply the same replacement on lines 59, 79, and 125.

- [ ] **Step 2: Update MeterReadingEntry concern**

In `app/controllers/concerns/meter_reading_entry.rb`, line 20:
```ruby
# Before:
@show_zone_unit = current_user.system_admin?
# After:
@show_zone_unit = current_user.system_wide_scope?
```

- [ ] **Step 3: Update FreshnessIndicatable concern**

In `app/controllers/concerns/freshness_indicatable.rb`, line 13:
```ruby
# Before:
if current_user.system_admin?
# After:
if current_user.system_wide_scope?
```

- [ ] **Step 4: Update BillingController**

In `app/controllers/billing_controller.rb`, lines 16 and 103 — replace `current_user.system_admin?` with `current_user.system_wide_scope?`.

- [ ] **Step 5: Update UnitConfigController**

In `app/controllers/unit_config_controller.rb`, replace `current_user.system_admin?` with `current_user.system_wide_scope?` on lines 11, 68, 83, 102, 113, 169 (6 occurrences).

- [ ] **Step 6: Update ContactPointsController**

In `app/controllers/contact_points_controller.rb`:
- Line 42: `if current_user.system_wide_scope? || current_zone_manager?`
- Line 144: `if current_user.system_wide_scope?`

- [ ] **Step 7: Update ElectricitySupplyController**

In `app/controllers/electricity_supply_controller.rb`, line 60:
```ruby
# Before:
return if accessible_main_meters.exists? || current_user.system_admin?
# After:
return if accessible_main_meters.exists? || current_user.system_wide_scope?
```

- [ ] **Step 8: Update SidebarHelper**

In `app/helpers/sidebar_helper.rb`, add DC case in `allowed_sidebar_items` (line 36). DC sees everything SA sees:
```ruby
when :division_commander
  %i[dashboard billing history electricity_supply meter_entries pump_entries
     contact_points blocks groups unit_config
     zones units pump_allocations pricing ranks
     users audit_logs]
```

Insert this between the `:system_admin` case and the `:unit_admin` case.

- [ ] **Step 9: Update DashboardSummary**

In `app/services/dashboard_summary.rb`, line 11-12, add `:division_commander`:
```ruby
case @user.role.to_sym
when :system_admin, :division_commander then build_system_admin_summary
when :unit_admin, :commander then build_unit_summary
else
  OpenStruct.new(role: @user.role.to_sym, warnings: [])
end
```

- [ ] **Step 10: Update dashboard view**

In `app/views/dashboard/show.html.erb`:

Line 18 — DC uses the system_admin partial:
```erb
<% if @summary.role == :system_admin || @summary.role == :division_commander %>
```

Line 6 — open period banner. DC is read-only like commander, does NOT see the banner. No change needed (DC is not `unit_admin?` and not `system_admin?`).

- [ ] **Step 11: Update 10 remaining view files**

Replace `current_user.system_admin?` with `current_user.system_wide_scope?` in:

1. `app/views/blocks/index.html.erb:9` — `show_zone_unit = current_user.system_wide_scope?`
2. `app/views/contact_points/index.html.erb:12` — same pattern
3. `app/views/groups/index.html.erb:9` — same pattern
4. `app/views/units/index.html.erb:12` — `if current_user.system_wide_scope?`
5. `app/views/unit_config/show.html.erb:3` — `!current_user.system_wide_scope?`
6. `app/views/unit_config/show.html.erb:10` — `if current_user.system_wide_scope?`
7. `app/views/pump_entries/show.html.erb:7` — `if current_user.system_wide_scope?`
8. `app/views/users/index.html.erb:11` — `show_zone_unit = current_user.system_wide_scope?`
9. `app/views/meter_entries/show.html.erb:7` — `if current_user.system_wide_scope?`
10. `app/views/pump_allocations/index.html.erb:13` — `if current_user.system_wide_scope?`
11. `app/views/pump_allocations/index.html.erb:51` — `current_user.system_wide_scope?`
12. `app/views/billing/show.html.erb:14` — `if current_user.system_wide_scope?`

- [ ] **Step 12: Run tests**

Run: `bin/docker rspec spec/models/user_spec.rb spec/abilities/`
Expected: Existing tests still pass (new role doesn't break old behavior).

- [ ] **Step 13: Commit**

```bash
git add app/controllers/ app/helpers/ app/services/ app/views/
git commit -m "feat(role): division_commander navigation, display, and filter logic"
```

---

## Task 4: Guardrail Matrices (access + behavior)

Expand from 6→7 roles in both matrices so the completeness guardrails pass.

**Files:**
- Modify: `spec/support/role_access_matrix.rb`
- Modify: `spec/support/role_behavior_matrix.rb`
- Modify: `spec/requests/role_access_matrix_spec.rb`
- Modify: `spec/support/role_behavior_scenarios.rb`

- [ ] **Step 1: Update RoleAccessMatrix**

In `spec/support/role_access_matrix.rb`:

Line 16 — add `:dc` to ROLES:
```ruby
ROLES = %i[sa dc ua_zm ua cmd_zm cmd tech].freeze
```

Line 19 — add DC label:
```ruby
ROLE_LABELS = { sa: "SA", dc: "DC", ua_zm: "UA-ZM", ua: "UA", cmd_zm: "CMD-ZM", cmd: "CMD", tech: "TECH" }.freeze
```

Lines 35-81 — add `dc:` to every PAGES entry. DC has the same access as SA (`:ok` everywhere SA is `:ok`, `:redirect` on backups):

```ruby
"dashboard"          => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"billing"            => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"history"            => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"electricity_supply" => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :redirect, cmd_zm: :ok, cmd: :redirect, tech: :redirect } },
"meter_entries"      => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"pump_entries"       => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"contact_points"     => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"blocks"             => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"groups"             => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"unit_config"        => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
"zones"              => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
"units"              => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
"pump_allocations"   => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :ok, ua: :redirect, cmd_zm: :ok, cmd: :redirect, tech: :redirect } },
"pricing"            => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
"ranks"              => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
"users"              => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } },
"audit_logs"         => { ..., expect: { sa: :ok, dc: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } },
"backups"            => { ..., expect: { sa: :redirect, dc: :redirect, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } },
```

Update line 85 comment: "mọi trang × 7 vai trò"

- [ ] **Step 2: Update role_access_matrix_spec.rb build_user**

In `spec/requests/role_access_matrix_spec.rb`, add DC case in `build_user` (line 22-31):
```ruby
def build_user(role)
  case role
  when :sa     then create(:user, :system_admin)
  when :dc     then create(:user, :division_commander)
  when :ua_zm  then create(:user, :unit_admin, unit: unit_manager)
  when :ua     then create(:user, :unit_admin, unit: unit_other)
  when :cmd_zm then create(:user, :commander, unit: unit_manager)
  when :cmd    then create(:user, :commander, unit: unit_other)
  when :tech   then create(:user, :technician)
  else raise ArgumentError, "Unknown role #{role.inspect}"
  end
end
```

Update comments referencing "6 vai trò" → "7 vai trò" and "6 roles" → "7 roles".

- [ ] **Step 3: Update RoleBehaviorMatrix**

In `spec/support/role_behavior_matrix.rb`, no structural change needed. The 4 dimensions stay the same. DC behavior does NOT add a new dimension — DC is read-only like commander but system-wide. The existing `commander_readonly` shared example tests CMD/CMD-ZM users; DC should be added to those user lists in the scenarios (Task 4, step 4).

However, if any behavior dimension's `na` reason references "6 vai trò" or specifically excludes DC implicitly, update the text. For most pages, the existing `na` reasons still hold for DC (e.g., "Commander không truy cập" → now DC CAN access, so some `na` reasons need updating).

**Pages needing behavior updates for DC:**
- Pages where commander_readonly `applies` → DC must be added to `commander_users` in scenarios
- Pages where commander_readonly is `na` because "Commander không truy cập" → check if DC accesses that page (DC accesses zones, units, pricing, ranks, users, audit_logs — currently `na` because CMD can't access). For these settings/system pages, the inputs are CRUD-style (edit forms) not inline inputs. DC can see the index (read-only) but can't access edit forms → commander_readonly is still `na` (no inline inputs to disable on index).

No changes needed to the BEHAVIORS hash itself — the dimensions and reasons are about the UI structure, not about which roles exist. The scenarios (Task 4, step 4) handle the actual role→user mapping.

- [ ] **Step 4: Update RoleBehaviorScenarios**

In `spec/support/role_behavior_scenarios.rb`:

Update `make_user` method to handle `:dc`:
```ruby
def make_user(role, world)
  case role
  when :sa     then FactoryBot.create(:user, :system_admin)
  when :dc     then FactoryBot.create(:user, :division_commander)
  when :ua_zm, :ua  then FactoryBot.create(:user, :unit_admin, unit: unit_for(role, world))
  when :cmd_zm, :cmd then FactoryBot.create(:user, :commander, unit: unit_for(role, world))
  when :tech   then FactoryBot.create(:user, :technician)
  end
end
```

Update `accessible_non_sa_roles` — currently filters out `:sa` and `:tech`. DC is accessible and non-SA, so it will appear. But DC has system-wide scope (sees everything like SA), so it should NOT be in `unit_scoped_checks`. Update `unit_scoped_checks` and the data_scoping scenarios to exclude `:dc` from the scoping checks (DC sees everything).

For data_scoping scenarios that call `unit_scoped_checks`, DC should be treated like SA (sees all). The simplest approach: in each scenario method, after building unit_scoped_checks, do NOT add DC to checks (DC is like SA — sees everything, no scoping).

For commander_readonly scenarios, add DC user to `commander_users`:
```ruby
# In scenarios that build commander config:
dc_user = FactoryBot.create(:user, :division_commander)
commander_users: [cmd_user, cmd_zm_user, dc_user]
```

But DC sees the SA-style view (system-wide), while CMD sees unit-scoped view. The same input CSS selectors should work for both if the inputs use the same structure. Verify per page.

For zone_unit_columns scenarios, DC should show zone/unit columns (like SA). The shared example checks that SA shows columns and non-SA hides them. DC is non-SA but shows columns → the shared example needs DC excluded from the "hides columns" check, or DC needs to be in the "shows columns" users list.

Read `spec/support/shared_examples/requests/role_zone_unit_columns.rb` to understand the exact pattern and update scenarios accordingly.

- [ ] **Step 5: Run guardrail specs**

Run: `bin/docker rspec spec/requests/role_access_matrix_spec.rb spec/requests/role_behavior_matrix_spec.rb spec/lib/`
Expected: Completeness specs pass (7 roles declared, all pages covered).

- [ ] **Step 6: Commit**

```bash
git add spec/support/ spec/requests/role_access_matrix_spec.rb
git commit -m "feat(role): expand guardrail matrices from 6 to 7 roles for division_commander"
```

---

## Task 5: Ability + Integration Tests

**Files:**
- Modify: `spec/abilities/ability_spec.rb`
- Modify: `spec/requests/freshness_roles_spec.rb`

- [ ] **Step 1: Add DC ability tests**

In `spec/abilities/ability_spec.rb`, add a new `describe` block for division_commander (after the commander sections):

```ruby
describe "division_commander" do
  let(:user) { create(:user, :division_commander) }
  subject(:ability) { Ability.new(user) }

  it "read all business models system-wide" do
    [Zone, Unit, ContactPoint, Meter, MainMeter, Block, Group,
     Period, Rank, PumpAllocation,
     MeterReading, MainMeterReading, PersonnelEntry,
     NonEstablishmentSnapshot, UnitConfig, OtherDeduction, Calculation
    ].each do |klass|
      expect(ability).to be_able_to(:read, klass.new), "Expected read #{klass}"
    end
  end

  it "cannot create/update/destroy any business model" do
    [Zone, Unit, ContactPoint, Meter, MainMeter, Block, Group,
     Period, Rank, PumpAllocation,
     MeterReading, MainMeterReading, PersonnelEntry,
     NonEstablishmentSnapshot, UnitConfig, OtherDeduction, Calculation
    ].each do |klass|
      %i[create update destroy].each do |action|
        expect(ability).not_to be_able_to(action, klass.new),
          "Expected cannot #{action} #{klass}"
      end
    end
  end

  it "cannot recalculate" do
    expect(ability).not_to be_able_to(:recalculate, Calculation.new)
  end

  it "read users and audit logs" do
    expect(ability).to be_able_to(:read, User.new)
    expect(ability).to be_able_to(:read, PaperTrail::Version.new)
  end

  it "cannot manage users" do
    expect(ability).not_to be_able_to(:create, User.new)
    expect(ability).not_to be_able_to(:update, User.new)
    expect(ability).not_to be_able_to(:destroy, User.new)
  end

  it "cannot manage backups" do
    expect(ability).not_to be_able_to(:manage, Backup.new)
  end
end
```

- [ ] **Step 2: Update freshness_roles_spec.rb**

In `spec/requests/freshness_roles_spec.rb`, add DC test case. DC sees billing like SA, so the stale banner should show:

```ruby
it "CHIEU-do-tuoi-vai-tro: DC (division commander) sees the stale banner" do
  sign_in create(:user, :division_commander)
  get billing_path(period_id: period.id)
  expect(response.body).to include("freshness-stale")
  expect(response.body).to include(zone.name)
end
```

Add inside the `describe "roles that can see billing"` block.

- [ ] **Step 3: Run full test suite**

Run: `bin/docker rspec`
Expected: All tests pass. Fix any failures (likely from behavior scenarios needing DC user adjustments).

- [ ] **Step 4: Commit**

```bash
git add spec/abilities/ spec/requests/freshness_roles_spec.rb
git commit -m "test(role): add division_commander ability and freshness tests"
```

---

## Task 6: Business Confirmation Document

Create `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` following the pattern of `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md`.

**Files:**
- Create: `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md`

- [ ] **Step 1: Create the document**

Read `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` for the full format, then create `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` with:

**Required content:**
- Version: 2.1.0
- Date: current date
- Context: client requested a "Chỉ huy Sư đoàn" role for v1.2.0
- Section 1: confirm current role system works correctly (6 roles)
- Section 2: new role definition — "Chỉ huy Sư đoàn" (Division Commander)
  - Database enum: `division_commander`
  - Scope: system-wide (no unit assignment)
  - Permissions: read-only access to everything SA can see
  - Cannot: create/update/delete any data, recalculate, manage users, manage backups
- Section 3: per-page access and behavior table (all 18 pages × DC behavior)
  - Table columns: Trang | Truy cập | Dữ liệu thấy | Có thể sửa | Ghi chú
  - DC has `:ok` on all pages except backups
  - DC sees SA-style data (system-wide) on every page
  - DC cannot edit anything (inputs disabled, CRUD buttons hidden)
- Section 4: summary of confirmations needed

- [ ] **Step 2: Commit**

```bash
git add docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md
git commit -m "docs: add V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2 for division_commander role"
```

---

## Task 7: Documentation Update

**Files:**
- Modify: `docs/V2_HANH_VI_HE_THONG.md`

- [ ] **Step 1: Update section 1 (roles)**

In `docs/V2_HANH_VI_HE_THONG.md`:

Update the header: "6 vai trò thực tế" → "7 vai trò thực tế"

Update line 25 paragraph: "User model có 4 enum values" → "User model có 5 enum values (`system_admin`, `unit_admin`, `commander`, `division_commander`, `technician`), nhưng hệ thống có **7 vai trò** thực tế..."

Add DC row to the role table (after SA, before UA-ZM):

```markdown
| DC | Chỉ huy Sư đoàn | `role == "division_commander"` | Toàn hệ thống, chỉ xem |
```

Update line 36: "UA-ZM và CMD-ZM không phải role riêng trong database" — add context that DC IS a separate database enum value (no zone-manager variant).

- [ ] **Step 2: Update section 4 (page behaviors)**

Add DC row to each page behavior table in section 4. Pattern: DC sees same data as SA, cannot edit.

Example for Bảng tính tiền:
```markdown
| DC | Dropdown zone + unit | Tất cả đầu mối sinh hoạt | 30 (có Khu vực + Đơn vị) | Không |
```

Example for Nhập chỉ số:
```markdown
| DC | meter_entries: Tất cả | Tất cả bơm nước | Không (disabled) |
```

Add DC to all tables in section 4 (dashboard, billing, history, meter_entries, pump_entries, unit_config, pump_allocations, electricity_supply).

- [ ] **Step 3: Update version and changelog**

Bump version from `1.4.0` to `1.5.0`.
Update date to current date (21/06/2026).

Add changelog entry:
```markdown
### v1.5.0 (21/06/2026)

- Mục 1: 6→7 vai trò thực tế — thêm Chỉ huy Sư đoàn (DC, `division_commander`). Vai trò database riêng (không phải variant runtime), scope toàn hệ thống chỉ xem (tương tự SA nhưng không có quyền tạo/sửa/xóa/tính toán). Không thuộc đơn vị, không có biến thể zone-manager.
- Mục 4: thêm dòng DC vào mọi bảng hành vi trang. DC xem dữ liệu như SA (dropdown filter zone/unit, cột Khu vực + Đơn vị), inputs disabled, nút CRUD ẩn.
```

- [ ] **Step 4: Commit**

```bash
git add docs/V2_HANH_VI_HE_THONG.md
git commit -m "docs: update V2_HANH_VI_HE_THONG for 7th role division_commander"
```

---

## Task 8: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/docker rspec`
Expected: All tests pass including guardrail completeness.

- [ ] **Step 2: Run demo specs**

Run: `bin/docker demo`
Expected: Demo specs still pass (existing functionality unaffected).

- [ ] **Step 3: Run i18n/view checks**

Run: `bin/docker bash -c "bin/check-view-i18n.sh"` (if it exists)
Run: `bin/docker bash -c "bin/check-test-dimensions.sh"` (if it exists)

- [ ] **Step 4: Verify in browser (preview)**

Start dev server with `preview_start docker-dev`. Sign in as DC user. Verify:
1. Sidebar shows all items (same as SA)
2. Dashboard shows system-wide view (units table + zones table)
3. Billing shows all data with zone/unit filters + columns
4. Meter entries shows all data, inputs disabled
5. Contact points shows all data, no Thêm/Sửa/Xóa buttons
6. Zones page shows all zones, no CRUD buttons
7. Users page shows all users, no Thêm/Sửa/Xóa buttons

- [ ] **Step 5: Final commit (if any fixes)**

Fix any issues found during verification, commit with descriptive message.
