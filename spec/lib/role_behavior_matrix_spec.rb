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
