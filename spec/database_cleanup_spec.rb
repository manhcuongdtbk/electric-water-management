require "rails_helper"

# Guards the test-suite cleanup that keeps Issue #362 (order-dependent
# PG::UniqueViolation on idx_periods_only_one_open) from coming back. The real
# trigger was a committed open Period left in the database (e.g. by an
# interrupted non-transactional demo run); DatabaseCleanup.purge! is what the
# before(:suite) hook and the demo teardown use to wipe such leftovers.
RSpec.describe DatabaseCleanup do
  describe ".purge!" do
    it "removes a stray open period that would otherwise trip the global unique index" do
      create(:period, closed: false)
      expect(Period.where(closed: false).count).to eq(1)

      described_class.purge!

      expect(Period.count).to eq(0)
    end

    it "is a no-op (no error) on an already-empty database" do
      described_class.purge!
      expect { described_class.purge! }.not_to raise_error
    end

    it "never truncates Rails-owned bookkeeping tables" do
      expect(DatabaseCleanup::PROTECTED_TABLES).to include("schema_migrations", "ar_internal_metadata")
    end
  end
end
