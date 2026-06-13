# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/decimal/explicit_rounding_mode"

RSpec.describe RuboCop::Cop::Decimal::ExplicitRoundingMode, :config do
  it "registers an offense for round without a mode" do
    expect_offense(<<~RUBY)
      amount.round(2)
             ^^^^^ Round money/electricity with an explicit half-up mode (AGENTS): value.round(n, :half_up).
    RUBY
  end

  it "registers an offense for banker's rounding" do
    expect_offense(<<~RUBY)
      amount.round(2, :half_even)
             ^^^^^ Round money/electricity with an explicit half-up mode (AGENTS): value.round(n, :half_up).
    RUBY
  end

  it "accepts an explicit :half_up symbol" do
    expect_no_offenses(<<~RUBY)
      amount.round(2, :half_up)
    RUBY
  end

  it "accepts an explicit ROUND_HALF_UP constant" do
    expect_no_offenses(<<~RUBY)
      amount.round(2, BigDecimal::ROUND_HALF_UP)
    RUBY
  end
end
