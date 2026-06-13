# Chiều review "tuân AGENTS" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make code review (human + Claude via `/code-review`) check AGENTS conventions — machine-enforce the BigDecimal/rounding rule with two custom RuboCop cops, and surface the judgement-only dimensions (no-abbreviation, BigDecimal placement, six-role coverage, i18n) via a `/code-review` hook + CONTRIBUTING §8 checklist + PR-template checkbox.

**Architecture:** Two layers. **Layer 1 (machine):** custom cops `Decimal/NoFloatInCalculation` and `Decimal/ExplicitRoundingMode` under `lib/rubocop/cop/decimal/`, scoped via `.rubocop.yml` to the calculation layer (`app/models`, `app/services`), run by the existing `ruby-checks` CI job. **Layer 2 (judgement):** a `UserPromptSubmit` hook in `.claude/settings.json` injects the AGENTS review dimensions as `additionalContext` when `/code-review` is typed; the canonical checklist lives in `CONTRIBUTING.md` §8; a PR-template checkbox is the human gate.

**Tech Stack:** Ruby, RuboCop 1.86 (custom cop API `RuboCop::Cop::Base`, `def_node_matcher`), RSpec with `RuboCop::RSpec::ExpectOffense`, Docker (`bin/docker rspec`), bash/`jq` hooks.

**Spec:** `docs/superpowers/specs/2026-06-13-dimension-review-tuan-agents-design.md` (ADR-031).

**Branch:** `feature/agents-compliance-review-dimension` ← `develop` (already created; spec already committed as `c166e6f`). PR base `develop`, squash, body `Refs #329` (NOT `Closes` — #329 keeps part A open).

**Important convention:** Per AGENTS, do **not** run `rubocop` locally — CI's `ruby-checks` job covers the repo-wide run. Local verification here is the cop **unit specs** (`bin/docker rspec`) plus a direct bash test of the hook command. The repo-wide green run (proving zero false-positives on the 15 legitimate `.to_f` in `app/views/billing/show.xlsx.axlsx`) is confirmed by CI on the PR.

---

## Task 1: Stop Zeitwerk autoloading the cop namespace

The repo autoloads `lib/` via `config.autoload_lib(ignore: %w[assets tasks])`. The cop files define `RuboCop::...` (acronym), but Zeitwerk would expect `Rubocop::...` for `lib/rubocop/...` → `rails zeitwerk:check` (a CI gate) would fail. Add `rubocop` to the ignore list. RuboCop loads the cop files itself via `.rubocop.yml require:` (Task 4), so Rails never needs to autoload them.

**Files:**
- Modify: `config/application.rb:29`

- [ ] **Step 1: Edit the ignore list**

Change line 29 from:
```ruby
    config.autoload_lib(ignore: %w[assets tasks])
```
to:
```ruby
    config.autoload_lib(ignore: %w[assets tasks rubocop])
```

- [ ] **Step 2: Verify Zeitwerk is still happy**

Run: `bin/docker bash -c "bin/rails zeitwerk:check"`
Expected: ends with `All is good!` (no eager-load errors). Ignoring a not-yet-existing `lib/rubocop` path is harmless.

- [ ] **Step 3: Commit**

```bash
git add config/application.rb
git commit -m "chore(rubocop): exclude lib/rubocop from Rails autoload

Custom cops under lib/rubocop define the RuboCop:: acronym, which
Zeitwerk cannot infer; RuboCop requires them itself (ADR-031).

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Cop `Decimal/NoFloatInCalculation` (TDD)

Flags `.to_f` and `Float(...)` — float coercion that must not appear in calculation code. Scope (calc layer only) is applied in Task 4 via `.rubocop.yml`; the cop itself is path-agnostic.

**Files:**
- Create: `lib/rubocop/cop/decimal/no_float_in_calculation.rb`
- Test: `spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb`:
```ruby
# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/decimal/no_float_in_calculation"

RSpec.describe RuboCop::Cop::Decimal::NoFloatInCalculation, :config do
  it "registers an offense for .to_f" do
    expect_offense(<<~RUBY)
      total.to_f
            ^^^^ Use BigDecimal, not float, in calculation code (AGENTS); .to_f/Float() belong at the display boundary only.
    RUBY
  end

  it "registers an offense for Float()" do
    expect_offense(<<~RUBY)
      Float(total)
      ^^^^^ Use BigDecimal, not float, in calculation code (AGENTS); .to_f/Float() belong at the display boundary only.
    RUBY
  end

  it "accepts BigDecimal conversion" do
    expect_no_offenses(<<~RUBY)
      BigDecimal(total.to_s)
    RUBY
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bin/docker rspec spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb`
Expected: FAIL — `cannot load such file -- .../lib/rubocop/cop/decimal/no_float_in_calculation` (the cop file does not exist yet).

- [ ] **Step 3: Write the cop**

Create `lib/rubocop/cop/decimal/no_float_in_calculation.rb`:
```ruby
# frozen_string_literal: true

module RuboCop
  module Cop
    module Decimal
      # Chặn ép kiểu float trong tầng tính toán tiền/điện. AGENTS: dùng BigDecimal,
      # không dùng float cho tiền và điện. `.to_f` / `Float(...)` chỉ hợp lệ ở ranh
      # giới hiển thị/xuất Excel (axlsx, helper) — phạm vi giới hạn ở `.rubocop.yml`
      # (Include app/models, app/services). Xem ADR-031.
      #
      # @example
      #   # bad
      #   total.to_f
      #   Float(total)
      #
      #   # good
      #   BigDecimal(total.to_s)
      class NoFloatInCalculation < Base
        MSG = "Use BigDecimal, not float, in calculation code (AGENTS); " \
              ".to_f/Float() belong at the display boundary only."

        # `x.to_f` hoặc `Float(x)`
        def_node_matcher :float_coercion?, <<~PATTERN
          {(send _ :to_f) (send nil? :Float ...)}
        PATTERN

        def on_send(node)
          return unless float_coercion?(node)

          add_offense(node.loc.selector)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bin/docker rspec spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb`
Expected: PASS (3 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/rubocop/cop/decimal/no_float_in_calculation.rb spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb
git commit -m "feat(rubocop): add Decimal/NoFloatInCalculation cop

Flags .to_f and Float() so money/electricity values stay BigDecimal in
the calculation layer (AGENTS). Scope is applied via .rubocop.yml.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Cop `Decimal/ExplicitRoundingMode` (TDD)

Flags any `.round` that lacks an explicit half-up mode (`:half_up` symbol or a constant ending `ROUND_HALF_UP`). This catches both a missing mode and a banker's/half-even mode. Scope (calc layer only) is applied in Task 4.

**Files:**
- Create: `lib/rubocop/cop/decimal/explicit_rounding_mode.rb`
- Test: `spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb`:
```ruby
# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/decimal/explicit_rounding_mode"

RSpec.describe RuboCop::Cop::Decimal::ExplicitRoundingMode, :config do
  it "registers an offense for round without a mode" do
    expect_offense(<<~RUBY)
      amount.round(2)
             ^^^^^ Round money/electricity with an explicit half-up mode (AGENTS): value.round(n, :half_up).
    RUBY
  end

  it "registers an offense for banker's rounding" do
    expect_offense(<<~RUBY)
      amount.round(2, :half_even)
             ^^^^^ Round money/electricity with an explicit half-up mode (AGENTS): value.round(n, :half_up).
    RUBY
  end

  it "accepts an explicit :half_up symbol" do
    expect_no_offenses(<<~RUBY)
      amount.round(2, :half_up)
    RUBY
  end

  it "accepts an explicit ROUND_HALF_UP constant" do
    expect_no_offenses(<<~RUBY)
      amount.round(2, BigDecimal::ROUND_HALF_UP)
    RUBY
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bin/docker rspec spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb`
Expected: FAIL — `cannot load such file -- .../lib/rubocop/cop/decimal/explicit_rounding_mode`.

- [ ] **Step 3: Write the cop**

Create `lib/rubocop/cop/decimal/explicit_rounding_mode.rb`:
```ruby
# frozen_string_literal: true

module RuboCop
  module Cop
    module Decimal
      # Ép làm tròn tiền/điện bằng mode half-up tường minh. AGENTS: ROUND_HALF_UP
      # (5 làm tròn lên), không dùng ROUND_HALF_EVEN/banker's. Mọi `.round` ở tầng
      # tính toán phải kèm `:half_up` hoặc hằng `*ROUND_HALF_UP`. Phạm vi giới hạn ở
      # `.rubocop.yml` (Include app/models, app/services). Xem ADR-031.
      #
      # @example
      #   # bad
      #   amount.round(2)
      #   amount.round(2, :half_even)
      #   amount.round(2, BigDecimal::ROUND_HALF_EVEN)
      #
      #   # good
      #   amount.round(2, :half_up)
      #   amount.round(2, BigDecimal::ROUND_HALF_UP)
      class ExplicitRoundingMode < Base
        MSG = "Round money/electricity with an explicit half-up mode (AGENTS): " \
              "value.round(n, :half_up)."

        def on_send(node)
          return unless node.method?(:round)
          return if half_up_mode?(node)

          add_offense(node.loc.selector)
        end

        private

        def half_up_mode?(node)
          node.arguments.any? do |arg|
            (arg.sym_type? && arg.value == :half_up) ||
              (arg.const_type? && arg.const_name.to_s.end_with?("ROUND_HALF_UP"))
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bin/docker rspec spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb`
Expected: PASS (4 examples, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/rubocop/cop/decimal/explicit_rounding_mode.rb spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb
git commit -m "feat(rubocop): add Decimal/ExplicitRoundingMode cop

Flags .round without an explicit :half_up mode so money/electricity
rounding follows AGENTS (ROUND_HALF_UP, never banker's). Scope via
.rubocop.yml.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Register and scope the cops in `.rubocop.yml`

Load the cop files via `require:` and restrict each to the calculation layer (`app/models`, `app/services`). Display/Excel boundary (`*.axlsx`, helpers) is outside `Include` so the 15 legitimate `.to_f` are not flagged.

**Files:**
- Modify: `.rubocop.yml`

- [ ] **Step 1: Edit `.rubocop.yml`**

Replace the file's content with:
```yaml
inherit_from: .rubocop_todo.yml

# Omakase Ruby styling for Rails
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

# Custom cops enforcing the AGENTS BigDecimal/rounding conventions in the
# calculation layer (ADR-031). RuboCop loads these files itself (Rails autoload
# ignores lib/rubocop — see config/application.rb).
require:
  - ./lib/rubocop/cop/decimal/no_float_in_calculation.rb
  - ./lib/rubocop/cop/decimal/explicit_rounding_mode.rb

Decimal/NoFloatInCalculation:
  Enabled: true
  Include:
    - 'app/models/**/*.rb'
    - 'app/services/**/*.rb'

Decimal/ExplicitRoundingMode:
  Enabled: true
  Include:
    - 'app/models/**/*.rb'
    - 'app/services/**/*.rb'
```

(Preserve any commented house-style examples below if desired; they are inert.)

- [ ] **Step 2: Verify the cops load and the repo stays green**

Per AGENTS, rubocop is normally a CI concern, but verify once here because this change can turn CI red. Run:
`bin/docker bash -c "bundle exec rubocop --no-server --only Decimal/NoFloatInCalculation,Decimal/ExplicitRoundingMode"`
Expected: `no offenses detected` (calculation layer is currently clean; the 15 `.to_f` in `app/views/billing/show.xlsx.axlsx` are outside `Include` and not reported).

- [ ] **Step 3: Commit**

```bash
git add .rubocop.yml
git commit -m "build(rubocop): register and scope the Decimal/* cops

Loads the two custom cops and limits them to app/models and app/services
so the display/Excel boundary keeps its legitimate .to_f (ADR-031).

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `/code-review` hook injecting the AGENTS review dimensions

A `UserPromptSubmit` hook detects `/code-review` in the prompt and injects the four AGENTS dimensions as `additionalContext`. Bash + `jq`, fail-open (no match or missing `jq` → nothing injected). Mirrors the existing gh-pr-monitor hook style.

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Add the `UserPromptSubmit` block**

In `.claude/settings.json`, add a `"UserPromptSubmit"` key inside the existing `"hooks"` object (alongside `"PreToolUse"` and `"PostToolUse"`). The full `"hooks"` object becomes:
```json
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.prompt // empty' | grep -qF '/code-review' && echo '{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"AGENTS-compliance review dimension (this repo, see CONTRIBUTING section 8). Beyond diff correctness, also check: (1) No abbreviations - every new abbreviation in code, i18n, UI or commit must already be listed in docs/THUAT_NGU.md; this is semantic and not greppable. (2) BigDecimal placement - money and electricity values stay BigDecimal through the whole calculation; .to_f and Float() belong only at the display or Excel boundary; rounding uses ROUND_HALF_UP and only when displaying, never mid-calculation. The Decimal RuboCop cops catch the obvious cases in app/models and app/services; you check the indirect ones. (3) Six-role test coverage - confirm SA, UA-ZM, UA, CMD-ZM, CMD and TECH are each covered or explicitly deferred. (4) i18n - user-facing strings go through t(...) and config/locales/vi.yml; interim manual check until the i18n CI guardrail lands.\"}}' || true"
          }
        ]
      }
    ],
    "PreToolUse": [
```
(Keep the existing `PreToolUse` and `PostToolUse` arrays unchanged after it. Ensure the JSON stays valid — one comma after the `UserPromptSubmit` array's closing `]`.)

- [ ] **Step 2: Verify the file is valid JSON**

Run: `jq empty .claude/settings.json && echo OK`
Expected: `OK` (no parse error).

- [ ] **Step 3: Verify the hook command matches and emits context**

Run: `echo '{"prompt":"/code-review high"}' | jq -r '.prompt // empty' | grep -qF '/code-review' && echo MATCH || echo NOMATCH`
Expected: `MATCH`.

Run: `echo '{"prompt":"please refactor billing"}' | jq -r '.prompt // empty' | grep -qF '/code-review' && echo MATCH || echo NOMATCH`
Expected: `NOMATCH` (no injection on unrelated prompts).

- [ ] **Step 4: Verify the emitted JSON is well-formed**

Run (the exact command body, fed a matching prompt, piped through `jq` to validate):
```bash
echo '{"prompt":"/code-review"}' | jq -r '.prompt // empty' | grep -qF '/code-review' && echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"probe"}}' | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null && echo OK
```
Expected: `OK` (confirms the output shape is valid; the real command uses the same shape with the full text).

- [ ] **Step 5: Commit**

```bash
git add .claude/settings.json
git commit -m "ci(hooks): inject AGENTS review dimensions on /code-review

A UserPromptSubmit hook adds the four AGENTS-compliance review checks as
additionalContext when /code-review is invoked, so Claude applies them
even when a human skims (ADR-031). Fail-open, jq-based.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Canonical checklist in `CONTRIBUTING.md` §8

Add the single-source "Chiều review tuân AGENTS" subsection. The hook and PR checkbox point here. `CONTRIBUTING.md` is a root meta file → **not** versioned (ADR-002), no changelog bump.

**Files:**
- Modify: `CONTRIBUTING.md` (end of §8, after the ADR-030 `doc-governance` paragraph)

- [ ] **Step 1: Append the subsection**

After the `**CI guardrail truy vết chiều test (ADR-030):** ...` paragraph in §8, add:
```markdown

**Chiều review "tuân AGENTS" (ADR-031):** review code — người và Claude khi chạy `/code-review` — không chỉ soi đúng/sai chức năng của diff mà còn kiểm tuân thủ quy ước AGENTS. Bốn chiều và cách phủ:

| Chiều | Kiểm gì | Cơ chế phủ |
|---|---|---|
| **i18n** | Chữ người dùng qua `t(...)` + `config/locales/vi.yml`; không hard-code tiếng Việt | Tạm bằng mắt người (mục A của #329 sẽ máy-ép sau) |
| **Không viết tắt** | Mọi viết tắt mới (code/i18n/giao diện/commit) có trong `docs/THUAT_NGU.md` | Người/AI — ngữ nghĩa, máy không grep được |
| **BigDecimal tiền/điện** | Tiền/điện giữ BigDecimal xuyên suốt; `.to_f`/`Float()` chỉ ở ranh giới hiển thị/Excel; làm tròn `ROUND_HALF_UP` chỉ khi hiển thị | Custom RuboCop cop `Decimal/*` (job `ruby-checks`) bắt ca rõ ràng ở `app/models`,`app/services`; người/AI soi ca lẩn đường vòng |
| **Phủ đủ 6 vai trò** | Test phủ SA, UA-ZM, UA, CMD-ZM, CMD, TECH hoặc hoãn tường minh | ADR-030 ép liên kết chiều test ↔ test; người/AI soi đủ-6-vai |

Bề mặt ép: (1) cop `Decimal/*` máy-ép phần BigDecimal; (2) hook `UserPromptSubmit` (`.claude/settings.json`) bơm chiều này vào Claude khi gõ `/code-review`; (3) checkbox trong `.github/pull_request_template.md`. Không sửa prompt `/code-review`/review subagent vì chúng là plugin toàn cục, không version-controlled trong repo. Chi tiết + lý do: ADR-031 (`docs/superpowers/specs/2026-06-13-dimension-review-tuan-agents-design.md`).
```

- [ ] **Step 2: Verify internal links resolve**

Run: `bash .github/scripts/check-doc-links.sh`
Expected: exit 0 (the referenced spec path and `docs/THUAT_NGU.md` exist).

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs(contributing): add AGENTS-compliance review dimension to section 8

Canonical checklist of the four AGENTS review dimensions and how each is
covered (Decimal/* cops, /code-review hook, PR checkbox) per ADR-031.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: PR-template checkbox (human gate)

**Files:**
- Modify: `.github/pull_request_template.md`

- [ ] **Step 1: Add a checkbox to the Traceability checklist**

After the `- [ ] Tests cover the changed behaviour (\`bin/docker rspec\`).` line, add:
```markdown
- [ ] AGENTS conventions reviewed (CONTRIBUTING §8): i18n via `t(...)`, no abbreviations outside `docs/THUAT_NGU.md`, BigDecimal for money/electricity, six-role test coverage.
```

- [ ] **Step 2: Verify internal links resolve**

Run: `bash .github/scripts/check-doc-links.sh`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/pull_request_template.md
git commit -m "docs(pr-template): add AGENTS-compliance review checkbox

Human gate for the four AGENTS review dimensions, pointing to
CONTRIBUTING section 8 (ADR-031).

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Full verification and open the PR

**Files:** none (verification + PR).

- [ ] **Step 1: Run the cop specs together**

Run: `bin/docker rspec spec/rubocop/cop/decimal/`
Expected: PASS (7 examples, 0 failures).

- [ ] **Step 2: Run the full suite to confirm nothing else broke**

Run: `bin/docker rspec`
Expected: the full suite passes (same baseline as before this branch).

- [ ] **Step 3: Confirm Zeitwerk and the cops are consistent**

Run: `bin/docker bash -c "bin/rails zeitwerk:check"`
Expected: `All is good!`

- [ ] **Step 4: Push and open the PR**

```bash
git push -u origin feature/agents-compliance-review-dimension
gh pr create --base develop \
  --title "feat: AGENTS-compliance review dimension (ADR-031)" \
  --body "$(cat <<'EOF'
## Summary

Implements part B of #329: make code review check AGENTS conventions, not just diff correctness. Two layers.

**Layer 1 — machine (custom RuboCop cops, `ruby-checks` job):**
- `Decimal/NoFloatInCalculation` — flags `.to_f` / `Float()` in `app/models`, `app/services`.
- `Decimal/ExplicitRoundingMode` — flags `.round` without an explicit `:half_up` mode in the same layer.
- Both run green today (the calculation layer has zero `.to_f`/`.round`; the 15 legitimate `.to_f` live at the Excel boundary, out of scope) → forward regression net.

**Layer 2 — judgement (hook + checklist):**
- `UserPromptSubmit` hook injects the four AGENTS dimensions as `additionalContext` on `/code-review`.
- Canonical checklist in `CONTRIBUTING.md` §8; PR-template checkbox as the human gate.

Does not touch the global `/code-review` plugin (not version-controlled here). i18n automation stays part A; no-abbreviation and BigDecimal-placement reasoning remain human/AI (see ADR-031 Limits).

## Linked change

Refs #329
EOF
)"
```

- [ ] **Step 5: Monitor CI and report**

After the PR is created, watch `gh pr checks <number>` (a hook will remind you) until all checks finish. The `ruby-checks` job runs the new cops repo-wide and `doc-governance`/`tests` run as usual (this PR touches code → full CI). Report pass/fail. If `ruby-checks` is red on a real `.to_f`/`.round` the cops correctly flagged, fix the source or add a justified `# rubocop:disable Decimal/...` inline.

---

## Self-Review notes (for the implementer)

- **Spec coverage:** Layer-1 cops = Tasks 2–4; Layer-2 hook = Task 5; canonical checklist = Task 6; PR checkbox = Task 7; Zeitwerk safety (implied by putting cops under `lib/`) = Task 1; verification incl. repo-wide green = Tasks 4 & 8. `docs/THUAT_NGU.md` needs **no** change (no new registered abbreviation; "BigDecimal", "RuboCop", "cop" are standard tool terms) — confirmed against ADR-024's glossary guardrail, which only checks that already-listed terms stay defined.
- **No placeholders:** every cop/spec/hook/doc block is complete and literal.
- **Type/name consistency:** cop class names `RuboCop::Cop::Decimal::NoFloatInCalculation` and `RuboCop::Cop::Decimal::ExplicitRoundingMode`, cop ids `Decimal/NoFloatInCalculation` and `Decimal/ExplicitRoundingMode`, and file paths match across the spec files, cop files, `.rubocop.yml`, and CONTRIBUTING §8.
