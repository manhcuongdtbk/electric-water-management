require "rails_helper"
# lib/generators is excluded from zeitwerk (config.autoload_lib ignore), so load
# the generator explicitly by path.
require Rails.root.join("lib", "generators", "demo", "spec", "spec_generator").to_s

RSpec.describe Demo::SpecGenerator do
  let(:tmp) { Rails.root.join("tmp", "demo_generator_spec") }

  around do |example|
    FileUtils.rm_rf(tmp)
    example.run
    FileUtils.rm_rf(tmp)
  end

  # Run the generator into a throwaway destination root, silencing its
  # "create ..." status output so the spec log stays clean.
  def generate(name)
    original = $stdout
    $stdout = StringIO.new
    described_class.start([name], destination_root: tmp.to_s)
  ensure
    $stdout = original
  end

  def read(relative)
    File.read(tmp.join(relative))
  end

  it "creates a demo spec from an underscored feature name" do
    generate("meter_entries")
    expect(File).to exist(tmp.join("spec/demo/meter_entries_demo_spec.rb"))
  end

  it "underscores a CamelCase feature name into the filename" do
    generate("PumpAllocation")
    expect(File).to exist(tmp.join("spec/demo/pump_allocation_demo_spec.rb"))
  end

  it "fills the skeleton with the demo boilerplate and an NV anchor placeholder" do
    generate("meter_entries")
    content = read("spec/demo/meter_entries_demo_spec.rb")

    expect(content).to include("type: :demo")
    expect(content).to include("DemoRecorder.new(self)")
    expect(content).to include('include_context "demo seeded world"')
    expect(content).to include("demo_nv:")
    expect(content).to include("NV-")
    expect(content).to include("caption:")
    expect(content).to include('RSpec.describe "Demo: Meter entries"')
  end

  it "seeds the good-demo patterns: golden example pointer, highlight, narrate, the honesty note and the quality checklist (ADR-059)" do
    generate("meter_entries")
    content = read("spec/demo/meter_entries_demo_spec.rb")

    # Tier 2: every new demo starts pointed at the golden example (TN1)…
    expect(content).to include("cot_khac_he_so_don_vi_demo_spec.rb")
    # …with the six-point "demo tốt" checklist inline (ADR-059)…
    expect(content).to include("ADR-059")
    expect(content).to include("Show, don't tell")
    # …a highlight placeholder so the result is shown, not just told…
    expect(content).to include("demo.highlight(")
    # …a narrate placeholder to tell the customer's story…
    expect(content).to include("demo.narrate(")
    # …and the honesty-about-the-medium note (do not act out Excel).
    expect(content).to include(".xlsx")
  end

  it "produces parseable Ruby" do
    generate("meter_entries")
    content = read("spec/demo/meter_entries_demo_spec.rb")
    expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
  end
end
