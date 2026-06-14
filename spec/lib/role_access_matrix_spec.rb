# Unit tests for the role-coverage guardrail policy (#359, ADR-056).
# These exercise the pure functions in RoleAccessMatrix with synthetic input to
# prove the guardrail actually BITES — without booting the app or touching the DB.
# This is the "test kèm guardrail" that replaces a bash .test.sh in the bash family.
require "rails_helper"

RSpec.describe RoleAccessMatrix do
  describe "PAGES data integrity" do
    it "covers all 6 roles for every page (no role gaps in the real matrix)" do
      expect(described_class.role_gaps).to eq({})
    end

    it "uses only known roles in every expectation hash" do
      described_class::PAGES.each do |slug, config|
        extra = config.fetch(:expect).keys - described_class::ROLES
        expect(extra).to be_empty, "#{slug} expects unknown role(s): #{extra.inspect}"
      end
    end

    it "uses only :ok / :redirect outcomes" do
      outcomes = described_class::PAGES.values.flat_map { |c| c.fetch(:expect).values }.uniq
      expect(outcomes - %i[ok redirect]).to be_empty
    end
  end

  describe ".controller_name_for" do
    it "maps a snake_case slug to its controller class name" do
      expect(described_class.controller_name_for("contact_points")).to eq("ContactPointsController")
      expect(described_class.controller_name_for("dashboard")).to eq("DashboardController")
    end
  end

  describe ".coverage_gaps" do
    let(:declared) { described_class.declared_controllers }

    it "reports no gaps when actual controllers exactly match the matrix" do
      gaps = described_class.coverage_gaps(declared)
      expect(gaps).to eq(missing: [], stale: [])
    end

    it "flags a page controller that exists but is missing from the matrix" do
      actual = declared + ["NewThingController"]
      expect(described_class.coverage_gaps(actual)[:missing]).to eq(["NewThingController"])
    end

    it "flags a matrix entry whose controller no longer exists (stale)" do
      removed = declared.first
      actual = declared - [removed]
      expect(described_class.coverage_gaps(actual)[:stale]).to eq([removed])
    end

    it "never counts excluded controllers as missing" do
      actual = declared + described_class::EXCLUDED_CONTROLLERS
      expect(described_class.coverage_gaps(actual)[:missing]).to be_empty
    end
  end

  describe ".role_gaps" do
    it "would flag a page that omits a role (proves the role check bites)" do
      incomplete = { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok } # missing :tech
      stub = { "fake_page" => { category: "X", path: :root_path, expect: incomplete } }
      stub_const("RoleAccessMatrix::PAGES", stub)
      expect(described_class.role_gaps).to eq("fake_page" => [:tech])
    end
  end
end
