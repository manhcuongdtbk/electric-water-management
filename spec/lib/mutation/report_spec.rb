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
