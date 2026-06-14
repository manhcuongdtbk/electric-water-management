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

  it "does NOT mutate an integer that lives inside a string literal" do
    pairs = tos('d / BigDecimal("100")')
    expect(pairs).not_to include(%w[100 0])
    expect(pairs).not_to include(%w[100 101])
  end

  it "mutates a bare integer literal to 0 and n+1" do
    pairs = tos("remaining = d * 100")
    expect(pairs).to include(%w[100 0]).and include(%w[100 101])
  end

  it "does not emit a no-op 0->0 mutation for a literal zero" do
    pairs = tos("x = 0")
    expect(pairs).to include(%w[0 1])
    expect(pairs).not_to include(%w[0 0])
  end

  it "flips if/unless and the zero? predicate" do
    expect(tos("return if b.zero?")).to include(%w[if unless]).and include(%w[zero? nonzero?])
  end

  it "NEVER mutates operators inside string literals" do
    expect(tos('t("a + b * c")')).to eq([])
  end

  it "NEVER mutates operators inside comments" do
    pairs = tos("x = 1 # a + b")
    expect(pairs).to include(%w[1 0]).and include(%w[1 2])
    expect(pairs.map(&:last)).not_to include("-")
  end
end
