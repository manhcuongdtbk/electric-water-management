# Mutation testing harness (billing core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A minimal, project-owned mutation-testing harness (Ripper-based) that mutates the billing/electricity calculation core and reports surviving mutants, run on demand via `rake mutation:core`.

**Architecture:** Three pure-ish units under `lib/mutation/` — `Operators` (Ripper tokenize → mutation list), `Runner` (apply one mutation → run that subject's spec → classify killed/survived → restore), `Report` (counts + survivor listing). A rake task wires config (`config/mutation.yml` subjects, `config/mutation_ignores.yml` equivalents) into the runner. The harness's own unit tests run in the normal suite; the *execution* over the calc core is manual/periodic.

**Tech Stack:** Ruby 3.4.3, `Ripper` (stdlib), Rails 8 rake, RSpec. No external gems (per ADR-056).

**Spec:** `docs/superpowers/specs/2026-06-14-mutation-testing-loi-tinh-toan-design.md` (ADR-056, Issue #358).

**Conventions:** Code/log English. Run tests with `bin/docker rspec <path>` (sets RAILS_ENV=test). Commit per task (Conventional Commits, subject not starting with an UPPERCASE token).

---

## File Structure

- Create `lib/mutation/change.rb` — value object for one mutation (`Mutation::Change`).
- Create `lib/mutation/operators.rb` — `Mutation::Operators.changes_for(source, path:)`.
- Create `lib/mutation/report.rb` — `Mutation::Report`.
- Create `lib/mutation/runner.rb` — `Mutation::Runner` + `Mutation::Subject` + `Mutation::SystemSpecRunner`.
- Create `config/mutation.yml` — subject → spec mapping.
- Create `config/mutation_ignores.yml` — equivalent-mutant ignore list (starts empty with a documented schema).
- Create `lib/tasks/mutation.rake` — `mutation:core[subject]`.
- Modify `config/application.rb:32` — add `mutation` to `autoload_lib(ignore:)` so `lib/mutation/**` is required explicitly (mirrors `tasks`), keeping `zeitwerk:check` green and out of production eager-load.
- Create `spec/lib/mutation/operators_spec.rb`, `spec/lib/mutation/runner_spec.rb`, `spec/lib/mutation/report_spec.rb`.
- (Task 6) Modify existing `spec/services/{loss_calculator,pump_allocation_calculator,summary_calculator}_spec.rb` to kill high-value survivors.
- (Task 7, optional) Create `.github/workflows/mutation.yml` — `workflow_dispatch` manual run.

---

## Task 1: `Mutation::Change` value object

**Files:**
- Create: `lib/mutation/change.rb`

- [ ] **Step 1: Write the value object**

```ruby
# frozen_string_literal: true

module Mutation
  # One mutation: replace `from` with `to` at a 1-based line / 0-based column.
  # `label` groups mutations by operator for reporting (e.g. "arithmetic +→-").
  Change = Struct.new(:path, :line, :column, :from, :to, :label, keyword_init: true) do
    def location
      "#{path}:#{line}"
    end

    def description
      "#{from} -> #{to}  (#{label})"
    end

    # Stable key for the ignore-list (equivalent mutants).
    def ignore_key
      { "path" => path, "line" => line, "from" => from, "to" => to }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/mutation/change.rb
git commit -m "feat(mutation): add Change value object for a single mutation"
```

---

## Task 2: `Mutation::Operators` (Ripper-based mutation generation)

**Files:**
- Create: `lib/mutation/operators.rb`
- Test: `spec/lib/mutation/operators_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/mutation/change")
require Rails.root.join("lib/mutation/operators")

RSpec.describe Mutation::Operators do
  def tos(source)
    described_class.changes_for(source, path: "x.rb").map { |c| [c.from, c.to] }
  end

  it "swaps arithmetic operators + and -" do
    expect(tos("a + b")).to include(%w[+ -])
    expect(tos("a - b")).to include(%w[- +])
  end

  it "swaps * and /" do
    expect(tos("usage * c / b")).to include(%w[* /]).and include(%w[/ *])
  end

  it "swaps comparison and boundary operators" do
    expect(tos("x < y")).to include(%w[< <=])
    expect(tos("x > 0")).to include(%w[> >=])
    expect(tos("x == y")).to include(%w[== !=])
  end

  it "mutates the rounding mode symbol away from half_up" do
    expect(tos("n.round(2, :half_up)")).to include(%w[half_up half_even])
  end

  it "mutates integer literals to 0 and to n+1" do
    pairs = tos('d / BigDecimal("100")')
    # The literal lives inside the string here, so it must NOT be mutated...
    expect(pairs).not_to include(%w[100 0])
  end

  it "mutates a bare integer literal" do
    pairs = tos("remaining = d * 100")
    expect(pairs).to include(%w[100 0]).and include(%w[100 101])
  end

  it "flips if/unless and the zero? predicate" do
    expect(tos("return if b.zero?")).to include(%w[if unless]).and include(%w[zero? nonzero?])
  end

  it "NEVER mutates operators inside string literals" do
    expect(tos('t("a + b * c")')).to eq([])
  end

  it "NEVER mutates operators inside comments" do
    expect(tos("x = 1 # a + b")).to include(%w[1 0]).and include(%w[1 2])
    expect(tos("x = 1 # a + b").map(&:last)).not_to include("-")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/docker rspec spec/lib/mutation/operators_spec.rb`
Expected: FAIL — `cannot load such file -- .../lib/mutation/operators`

- [ ] **Step 3: Write the implementation**

```ruby
# frozen_string_literal: true

require "ripper"
require_relative "change"

module Mutation
  # Generates mutations for a Ruby source string using Ripper's lexer, so we
  # only ever touch real operator / literal / keyword tokens — never the bytes
  # inside string literals or comments.
  module Operators
    # token text => [replacement, label]; applies to :on_op tokens.
    OP_RULES = {
      "+"  => %w[- arithmetic],
      "-"  => %w[+ arithmetic],
      "*"  => %w[/ arithmetic],
      "/"  => %w[* arithmetic],
      "<"  => %w[<= boundary],
      ">"  => %w[>= boundary],
      "<=" => %w[< boundary],
      ">=" => %w[> boundary],
      "==" => %w[!= comparison],
      "!=" => %w[== comparison],
      "&&" => %w[|| logical],
      "||" => %w[&& logical]
    }.freeze

    # keyword / identifier swaps; applies to :on_kw and :on_ident tokens.
    WORD_RULES = {
      "if"      => %w[unless conditional],
      "unless"  => %w[if conditional],
      "half_up" => %w[half_even rounding],
      "zero?"   => %w[nonzero? predicate]
    }.freeze

    module_function

    def changes_for(source, path:)
      changes = []
      Ripper.lex(source).each do |(line, column), type, token, _state|
        rule = rule_for(type, token)
        next unless rule

        Array(rule).each do |to, label|
          changes << Change.new(path: path, line: line, column: column,
                                from: token, to: to, label: label)
        end
      end
      changes
    end

    def rule_for(type, token)
      case type
      when :on_op
        op = OP_RULES[token]
        op ? [[op[0], "#{op[1]} #{token}->#{op[0]}"]] : nil
      when :on_kw, :on_ident
        w = WORD_RULES[token]
        w ? [[w[0], "#{w[1]} #{token}->#{w[0]}"]] : nil
      when :on_int
        n = Integer(token, exception: false)
        n.nil? ? nil : [["0", "constant #{token}->0"], [(n + 1).to_s, "constant #{token}->#{n + 1}"]]
      when :on_float
        [["0", "constant #{token}->0"]]
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/docker rspec spec/lib/mutation/operators_spec.rb`
Expected: PASS (all examples green)

- [ ] **Step 5: Commit**

```bash
git add lib/mutation/operators.rb spec/lib/mutation/operators_spec.rb
git commit -m "feat(mutation): generate mutations via Ripper, skipping strings and comments"
```

---

## Task 3: `Mutation::Report`

**Files:**
- Create: `lib/mutation/report.rb`
- Test: `spec/lib/mutation/report_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/mutation/change")
require Rails.root.join("lib/mutation/report")

RSpec.describe Mutation::Report do
  def change(line:, label: "arithmetic +->-")
    Mutation::Change.new(path: "app/services/loss_calculator.rb", line: line,
                         column: 0, from: "+", to: "-", label: label)
  end

  it "counts killed, survived and ignored" do
    report = described_class.new(
      results: [
        { change: change(line: 10), status: :killed },
        { change: change(line: 20), status: :survived }
      ],
      ignored_count: 3
    )

    expect(report.total).to eq(2)
    expect(report.killed).to eq(1)
    expect(report.survived).to eq(1)
    expect(report.ignored).to eq(3)
  end

  it "lists survivors with location and description in to_s" do
    report = described_class.new(
      results: [{ change: change(line: 42), status: :survived }],
      ignored_count: 0
    )

    expect(report.to_s).to include("app/services/loss_calculator.rb:42")
    expect(report.to_s).to include("+ -> -")
    expect(report.to_s).to include("SURVIVED: 1")
  end

  it "reports clean when nothing survived" do
    report = described_class.new(
      results: [{ change: change(line: 10), status: :killed }],
      ignored_count: 0
    )
    expect(report.clean?).to be(true)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/docker rspec spec/lib/mutation/report_spec.rb`
Expected: FAIL — cannot load `lib/mutation/report`

- [ ] **Step 3: Write the implementation**

```ruby
# frozen_string_literal: true

module Mutation
  # Aggregates runner results into counts and a human-readable summary.
  # `results` is an array of { change: Mutation::Change, status: :killed | :survived }.
  class Report
    attr_reader :results, :ignored

    def initialize(results:, ignored_count:)
      @results = results
      @ignored = ignored_count
    end

    def total    = results.size
    def killed   = results.count { |r| r[:status] == :killed }
    def survived = results.count { |r| r[:status] == :survived }
    def survivors = results.select { |r| r[:status] == :survived }.map { |r| r[:change] }
    def clean? = survived.zero?

    def to_s
      lines = []
      lines << "Mutation testing — billing core"
      lines << "  TOTAL:    #{total}"
      lines << "  KILLED:   #{killed}"
      lines << "  SURVIVED: #{survived}"
      lines << "  IGNORED:  #{ignored} (equivalent mutants)"
      unless survivors.empty?
        lines << ""
        lines << "Survivors (assertions to strengthen):"
        survivors.each { |c| lines << "  #{c.location}  #{c.description}" }
      end
      lines.join("\n")
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/docker rspec spec/lib/mutation/report_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/mutation/report.rb spec/lib/mutation/report_spec.rb
git commit -m "feat(mutation): add Report summarizing killed/survived/ignored mutants"
```

---

## Task 4: `Mutation::Runner` (+ `Subject`, `SystemSpecRunner`)

**Files:**
- Create: `lib/mutation/runner.rb`
- Test: `spec/lib/mutation/runner_spec.rb`

- [ ] **Step 1: Write the failing test**

Uses a temp source file and a fake spec runner so no real RSpec is shelled out. The key invariants: each non-ignored mutation is applied once, classified per the spec runner, ignores are skipped, and **the source file is restored byte-for-byte at the end.**

```ruby
# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/mutation/change")
require Rails.root.join("lib/mutation/operators")
require Rails.root.join("lib/mutation/report")
require Rails.root.join("lib/mutation/runner")

RSpec.describe Mutation::Runner do
  let(:source) { "def add(a, b)\n  a + b\nend\n" }
  let(:tmp) { Rails.root.join("tmp", "mutation_subject_#{SecureRandom.hex(4)}.rb").to_s }

  before { File.write(tmp, source) }
  after  { File.delete(tmp) if File.exist?(tmp) }

  # Fake: a mutant "survives" (spec passes) only when the mutated file still
  # contains "a + b"; any real mutation flips it, so it is "killed".
  let(:spec_runner) do
    Class.new do
      def passes?(_spec_paths, path)
        File.read(path).include?("a + b")
      end
    end.new
  end

  it "applies each mutation, classifies it, and restores the file" do
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    report = described_class.new(subjects: [subject], spec_runner: spec_runner).run

    expect(report.total).to be > 0
    expect(report.survived).to eq(0)           # every real arithmetic mutation flips "a + b"
    expect(File.read(tmp)).to eq(source)        # restored byte-for-byte
  end

  it "skips mutations listed in the ignore set and counts them" do
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    ignores = [{ "path" => tmp, "line" => 2, "from" => "+", "to" => "-" }]
    report = described_class.new(subjects: [subject], spec_runner: spec_runner, ignores: ignores).run

    expect(report.ignored).to eq(1)
    expect(report.results.map { |r| r[:change].to }).not_to include("-")
  end

  it "restores the file even if the spec runner raises" do
    blowup = Class.new { def passes?(*) = raise("boom") }.new
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    expect { described_class.new(subjects: [subject], spec_runner: blowup).run }.to raise_error("boom")
    expect(File.read(tmp)).to eq(source)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/docker rspec spec/lib/mutation/runner_spec.rb`
Expected: FAIL — cannot load `lib/mutation/runner`

- [ ] **Step 3: Write the implementation**

```ruby
# frozen_string_literal: true

require_relative "change"
require_relative "operators"
require_relative "report"

module Mutation
  Subject = Struct.new(:path, :spec_paths, keyword_init: true)

  # Default spec runner: shells out to RSpec with --fail-fast. Exit 0 => the
  # suite passed under the mutation => the mutant SURVIVED.
  class SystemSpecRunner
    def passes?(spec_paths, _path)
      cmd = ["bundle", "exec", "rspec", *spec_paths, "--fail-fast", "--no-color"]
      system(*cmd, out: File::NULL, err: File::NULL)
    end
  end

  class Runner
    def initialize(subjects:, spec_runner: SystemSpecRunner.new, ignores: [])
      @subjects = subjects
      @spec_runner = spec_runner
      @ignores = ignores.map { |h| h.slice("path", "line", "from", "to") }
    end

    def run
      results = []
      ignored_count = 0

      @subjects.each do |subject|
        original = File.read(subject.path)
        changes = Operators.changes_for(original, path: subject.path)

        changes.each do |change|
          if ignored?(change)
            ignored_count += 1
            next
          end

          begin
            File.write(subject.path, apply(original, change))
            survived = @spec_runner.passes?(subject.spec_paths, subject.path)
            results << { change: change, status: survived ? :survived : :killed }
          ensure
            File.write(subject.path, original)
          end
        end
      end

      Report.new(results: results, ignored_count: ignored_count)
    end

    private

    def ignored?(change)
      @ignores.include?(change.ignore_key.slice("path", "line", "from", "to"))
    end

    # Replace `from` with `to` at the change's 1-based line / 0-based column.
    # Re-derived from the pristine `original` every time, so no offset drift.
    def apply(original, change)
      lines = original.lines
      idx = change.line - 1
      line = lines[idx].dup
      line[change.column, change.from.length] = change.to
      lines[idx] = line
      lines.join
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/docker rspec spec/lib/mutation/runner_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/mutation/runner.rb spec/lib/mutation/runner_spec.rb
git commit -m "feat(mutation): add Runner that applies, classifies and restores mutants"
```

---

## Task 5: Config files, autoload ignore, and the rake task

**Files:**
- Create: `config/mutation.yml`
- Create: `config/mutation_ignores.yml`
- Modify: `config/application.rb:32`
- Create: `lib/tasks/mutation.rake`

- [ ] **Step 1: Write the subject config**

`config/mutation.yml`:

```yaml
# Mutation-testing subjects for the billing/electricity core (ADR-056, Issue #358).
# Each subject maps a calculation source file to the spec(s) run to kill its mutants.
subjects:
  - path: app/services/calculation_orchestrator.rb
    specs: [spec/services/calculation_orchestrator_spec.rb]
  - path: app/services/loss_calculator.rb
    specs: [spec/services/loss_calculator_spec.rb]
  - path: app/services/pump_allocation_calculator.rb
    specs: [spec/services/pump_allocation_calculator_spec.rb]
  - path: app/services/summary_calculator.rb
    specs: [spec/services/summary_calculator_spec.rb]
```

- [ ] **Step 2: Write the (empty) ignore config with a documented schema**

`config/mutation_ignores.yml`:

```yaml
# Equivalent mutants (ADR-056): mutations that do NOT change observable behaviour
# (e.g. `x * 1` -> `x / 1`) and therefore always survive without being a test gap.
# Each entry is excluded from the run and counted as "ignored". Always give a reason.
#
# ignores:
#   - path: app/services/loss_calculator.rb
#     line: 53
#     from: "*"
#     to: "/"
#     reason: "multiplying by 1; equivalent"
ignores: []
```

- [ ] **Step 3: Keep `lib/mutation/**` out of autoload (zeitwerk + eager-load)**

Modify `config/application.rb:32` — add `mutation` to the ignore list:

```ruby
    config.autoload_lib(ignore: %w[assets tasks rubocop generators mutation])
```

- [ ] **Step 4: Write the rake task**

`lib/tasks/mutation.rake`:

```ruby
# frozen_string_literal: true

# Mutation testing for the billing/electricity core (ADR-056, Issue #358).
# Run manually / periodically — NOT part of the per-PR `tests` job.
#
#   bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake mutation:core"
#   bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake 'mutation:core[loss_calculator]'"
#
# Run on a clean git tree: the runner restores files via `ensure`, but a hard
# kill mid-run can leave a subject mutated — `git checkout -- app/services` recovers.
namespace :mutation do
  desc "Mutation-test the billing core (optional [subject] = source basename without .rb)"
  task :core, [:subject] => :environment do |_t, args|
    require Rails.root.join("lib/mutation/runner")

    config = YAML.load_file(Rails.root.join("config/mutation.yml")).fetch("subjects")
    ignores = (YAML.load_file(Rails.root.join("config/mutation_ignores.yml")) || {}).fetch("ignores", []) || []

    config = config.select { |s| File.basename(s["path"], ".rb") == args[:subject] } if args[:subject]
    abort("No matching subject for #{args[:subject].inspect}") if config.empty?

    subjects = config.map { |s| Mutation::Subject.new(path: s.fetch("path"), spec_paths: s.fetch("specs")) }
    report = Mutation::Runner.new(subjects: subjects, ignores: ignores).run

    puts report
    exit(1) unless report.clean?
  end
end
```

- [ ] **Step 5: Verify the task loads and zeitwerk is green**

Run: `bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rails zeitwerk:check"`
Expected: `All is good!` (no eager-load error from `lib/mutation`)

Run: `bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake -T mutation"`
Expected: lists `rake mutation:core[subject]`

- [ ] **Step 6: Commit**

```bash
git add config/mutation.yml config/mutation_ignores.yml config/application.rb lib/tasks/mutation.rake
git commit -m "feat(mutation): add mutation:core rake task and subject/ignore config"
```

---

## Task 6: Baseline run + kill high-value survivors

**Files:**
- Modify (as findings dictate): `spec/services/loss_calculator_spec.rb`, `spec/services/pump_allocation_calculator_spec.rb`, `spec/services/summary_calculator_spec.rb`
- Possibly add entries: `config/mutation_ignores.yml`
- Modify: spec doc baseline note in `docs/superpowers/specs/2026-06-14-mutation-testing-loi-tinh-toan-design.md`

- [ ] **Step 1: Run the baseline on a clean tree (may take several minutes)**

Run: `bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake mutation:core"`
Capture the full report (TOTAL/KILLED/SURVIVED/IGNORED + survivor list).

> If a single full run is too slow, run per subject: `rake 'mutation:core[loss_calculator]'`, then `pump_allocation_calculator`, `summary_calculator`, `calculation_orchestrator`.

- [ ] **Step 2: Triage survivors**

For each survivor, decide:
- **High-value** (arithmetic / rounding / constant in `LossCalculator`, `PumpAllocationCalculator`, `SummaryCalculator`) → strengthen the corresponding service spec to kill it (Step 3).
- **Equivalent** (no behaviour change, e.g. `* 1` ↔ `/ 1`, dead branch) → add to `config/mutation_ignores.yml` with a `reason`.
- **Low-value / needs large refactor** → record as a follow-up Issue; do not bloat this PR.

- [ ] **Step 3: For each high-value survivor, add a precise assertion**

Pattern — assert the exact per-entity BigDecimal, not just a total. Example for a loss survivor (`usage * c / b`): add an example with hand-computed expected loss for a specific meter so that `*`→`/` or `+`→`-` flips it. Then re-run that subject:

Run: `bin/docker exec app bash -lc "RAILS_ENV=test bundle exec rake 'mutation:core[loss_calculator]'"`
Expected: that survivor now KILLED.

- [ ] **Step 4: Re-run the full suite to ensure new assertions are green**

Run: `bin/docker rspec spec/services`
Expected: PASS

- [ ] **Step 5: Record the baseline in the spec**

Add a short "Baseline" note (counts before/after, and any accepted ignores or follow-up Issue numbers) to the `## Lịch sử thay đổi` of the spec, and bump the spec to `0.2.0` (per ADR-002, same commit).

- [ ] **Step 6: Commit**

```bash
git add spec/services config/mutation_ignores.yml docs/superpowers/specs/2026-06-14-mutation-testing-loi-tinh-toan-design.md
git commit -m "test(mutation): kill high-value billing-core survivors and record baseline"
```

---

## Task 7 (optional): manual CI workflow

Only do this if we want a one-click cloud run. It must NOT be a required check.

**Files:**
- Create: `.github/workflows/mutation.yml`

- [ ] **Step 1: Write a workflow_dispatch job**

```yaml
name: mutation
on:
  workflow_dispatch:
    inputs:
      subject:
        description: "Single subject basename (blank = all)"
        required: false
        default: ""
jobs:
  mutation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Prepare test database
        run: bin/rails db:test:prepare
        env:
          RAILS_ENV: test
      - name: Run mutation testing on the billing core
        run: bundle exec rake "mutation:core[${{ inputs.subject }}]"
        env:
          RAILS_ENV: test
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/mutation.yml
git commit -m "ci(mutation): add manual workflow_dispatch run for the billing core"
```

> Note: this job reuses the repo's existing Postgres/service setup — at execution time, align it with the `tests` job in `.github/workflows/ci.yml` (services, env, ruby version) rather than copying the generic snippet above verbatim.

---

## Self-Review notes

- **Spec coverage:** Operators (Task 2) = catalog §2; Runner+config (Tasks 4–5) = mechanism §1 + scope §3 + ignore §4; rake/CI (Task 5/7) = run cadence §6; baseline+survivors (Task 6) = DoD §6; glossary/ADR already landed in the docs commit. Upgrade path (ADR-056) is documentation-only, no task needed.
- **Type consistency:** `changes_for(source, path:)`, `Change` fields (`path/line/column/from/to/label`), `passes?(spec_paths, path)`, `Subject(path:, spec_paths:)`, `Report(results:, ignored_count:)` with `results` items `{ change:, status: }` — used identically across Tasks 1–5.
- **No placeholders:** every code step is concrete except Task 6 (inherently empirical — documents the procedure, not predetermined survivors) and Task 7 (optional, flagged).
