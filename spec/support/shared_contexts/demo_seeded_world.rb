# Shared setup for seeded demo journeys (type: :demo). Demo specs drive a real
# Playwright browser, so seed data must be COMMITTED for Puma's separate DB
# connections to see it — transactional fixtures wrap each example in a savepoint
# on the spec process's own connection, and data committed there is NOT visible
# to Puma's separate connections. We disable transactional tests for the
# including group and seed in before(:each); after(:each) clears the demo data so
# re-runs within the same rspec invocation stay predictable. The canonical setup
# for a recording session is still a full `db:reset && demo:seed`.
#
# Used by spec/demo/smoke_demo_spec.rb and by every spec produced by the
# `rails g demo:spec` scaffold (lib/generators/demo/spec). See ADR-050/051 in
# docs/superpowers/specs/2026-06-14-ai-soan-demo-scaffold-design.md.
RSpec.shared_context "demo seeded world" do
  self.use_transactional_tests = false

  before(:each) do
    # Start from a clean slate even if a previous demo example crashed before its
    # teardown — otherwise its committed open Period would linger.
    DatabaseCleanup.purge!
    # Load the curated demo dataset — commits data so Puma can read it.
    load Rails.root.join("db", "seeds", "demo.rb")
  end

  after(:each) do
    # Remove the committed demo data so it can't leak into later examples (these
    # specs are non-transactional). TRUNCATE ... CASCADE is FK-safe and, unlike
    # the previous hand-ordered `delete_all rescue nil`, never silently leaves a
    # committed open Period behind to trip idx_periods_only_one_open. See #362.
    DatabaseCleanup.purge!
  end
end
