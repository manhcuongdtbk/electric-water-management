require "rails_helper"

# Unit tests for the release demo bundler's testable decisions (ADR-047/048).
# The side-effecting orchestration (git/rspec/ffmpeg/copy) lives in
# lib/tasks/demo.rake and is exercised by the demo CI job, not here.
RSpec.describe DemoBundle do
  describe ".select_specs" do
    it "keeps customer-facing demo specs and drops the smoke spec" do
      changed = [
        "spec/demo/meter_entries_demo_spec.rb",
        "spec/demo/smoke_demo_spec.rb",
        "spec/demo/billing_demo_spec.rb"
      ]

      expect(described_class.select_specs(changed)).to eq(
        ["spec/demo/billing_demo_spec.rb", "spec/demo/meter_entries_demo_spec.rb"]
      )
    end

    it "ignores paths outside spec/demo and non-spec files" do
      changed = [
        "spec/demo/billing_demo_spec.rb",
        "spec/system/billing_spec.rb",
        "spec/demo/support_helper.rb",
        "app/models/period.rb"
      ]

      expect(described_class.select_specs(changed)).to eq(["spec/demo/billing_demo_spec.rb"])
    end

    it "de-duplicates and sorts, tolerating surrounding whitespace" do
      changed = [
        " spec/demo/zebra_demo_spec.rb ",
        "spec/demo/alpha_demo_spec.rb",
        "spec/demo/zebra_demo_spec.rb"
      ]

      expect(described_class.select_specs(changed)).to eq(
        ["spec/demo/alpha_demo_spec.rb", "spec/demo/zebra_demo_spec.rb"]
      )
    end

    it "returns an empty array when nothing matches (no-op range)" do
      expect(described_class.select_specs(["app/models/period.rb", "spec/demo/smoke_demo_spec.rb"])).to eq([])
    end
  end

  describe ".parse_manifest" do
    it "parses one JSON object per line and ignores blank lines" do
      jsonl = <<~JSONL
        {"video":"a.mp4","description":"A","file":"./spec/demo/a_demo_spec.rb","nv":"NV-01"}

        {"video":"b.mp4","description":"B","file":"./spec/demo/b_demo_spec.rb","nv":null}
      JSONL

      entries = described_class.parse_manifest(jsonl)

      expect(entries).to eq(
        [
          { video: "a.mp4", description: "A", file: "./spec/demo/a_demo_spec.rb", nv: "NV-01" },
          { video: "b.mp4", description: "B", file: "./spec/demo/b_demo_spec.rb", nv: nil }
        ]
      )
    end

    it "returns an empty array for an empty sidecar" do
      expect(described_class.parse_manifest("")).to eq([])
    end
  end

  describe ".manifest_markdown" do
    let(:clips) do
      [{ video: "login.mp4", description: "Đăng nhập", file: "./spec/demo/login_demo_spec.rb", nv: "NV-02" }]
    end

    it "lists each clip with its feature and business anchor" do
      markdown = described_class.manifest_markdown(range: "v1.1.0..HEAD", clips: clips, missing: [])

      expect(markdown).to include("Khoảng release: `v1.1.0..HEAD`")
      expect(markdown).to include("`login.mp4`")
      expect(markdown).to include("Đăng nhập")
      expect(markdown).to include("`spec/demo/login_demo_spec.rb`")
      expect(markdown).to include("NV-02")
      expect(markdown).not_to include("Demo spec không sinh ra clip")
    end

    it "renders a dash when a clip has no NV anchor" do
      anchorless = [{ video: "x.mp4", description: "X", file: "./spec/demo/x_demo_spec.rb", nv: nil }]

      expect(described_class.manifest_markdown(range: "r", clips: anchorless, missing: [])).to include("| — |")
    end

    it "surfaces demo specs that produced no clip" do
      markdown = described_class.manifest_markdown(
        range: "r", clips: clips, missing: ["spec/demo/broken_demo_spec.rb"]
      )

      expect(markdown).to include("## ⚠️ Demo spec không sinh ra clip")
      expect(markdown).to include("`spec/demo/broken_demo_spec.rb`")
    end

    it "notes an empty bundle explicitly" do
      expect(described_class.manifest_markdown(range: "r", clips: [], missing: [])).to include("Không có clip nào trong bộ")
    end
  end
end
