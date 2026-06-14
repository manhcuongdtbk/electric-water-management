# Deterministic, FK-safe purge of every application table in the test database.
#
# Why this exists: transactional fixtures roll back each example's OWN data, but
# they cannot undo rows COMMITTED outside that transaction. The demo specs
# (type: :demo, use_transactional_tests = false) seed via Puma's separate
# connection and an interrupted run — or a `demo:seed` accidentally pointed at
# the test database — can leave a committed open Period behind. Because
# `idx_periods_only_one_open` is a GLOBAL partial-unique index (at most one
# Period with closed = false), that single stray row makes every later
# `create(:period, closed: false)` in unrelated specs fail with
# PG::UniqueViolation, which surfaces as order-dependent flakiness. See Issue
# #362.
#
# TRUNCATE ... CASCADE removes the rows regardless of foreign-key order, so this
# is reliable where a hand-ordered `delete_all` chain is not.
module DatabaseCleanup
  # Tables RSpec/Rails own — never truncate these.
  PROTECTED_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  def self.purge!
    connection = ActiveRecord::Base.connection
    tables = connection.tables - PROTECTED_TABLES
    return if tables.empty?

    quoted = tables.map { |table| connection.quote_table_name(table) }.join(", ")
    connection.execute("TRUNCATE TABLE #{quoted} RESTART IDENTITY CASCADE")
  end
end
