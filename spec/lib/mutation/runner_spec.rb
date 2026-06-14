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
    expect(report.survived).to eq(0)     # every real arithmetic mutation flips "a + b"
    expect(File.read(tmp)).to eq(source) # restored byte-for-byte
  end

  it "skips mutations listed in the ignore set and counts them" do
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    ignores = [{ "path" => tmp, "line" => 2, "from" => "+", "to" => "-" }]
    report = described_class.new(subjects: [subject], spec_runner: spec_runner, ignores: ignores).run

    expect(report.ignored).to eq(1)
    expect(report.results.map { |r| r[:change].to }).not_to include("-")
  end

  it "ignores only the mutant at the given column when a line has several with the same from->to" do
    File.write(tmp, "def f(a, b, c)\n  a + b + c\nend\n") # two `+` on line 2 (columns 4 and 8)
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    ignores = [{ "path" => tmp, "line" => 2, "from" => "+", "to" => "-", "column" => 8 }]
    report = described_class.new(subjects: [subject], spec_runner: spec_runner, ignores: ignores).run

    ran_columns = report.results.map { |r| r[:change].column }
    expect(report.ignored).to eq(1)
    expect(ran_columns).to include(4)     # first `+` still mutated and run
    expect(ran_columns).not_to include(8) # second `+` excluded by column
  end

  it "restores the file even if the spec runner raises" do
    blowup = Class.new { def passes?(*) = raise("boom") }.new
    subject = Mutation::Subject.new(path: tmp, spec_paths: ["spec/none_spec.rb"])
    expect { described_class.new(subjects: [subject], spec_runner: blowup).run }.to raise_error("boom")
    expect(File.read(tmp)).to eq(source)
  end
end
