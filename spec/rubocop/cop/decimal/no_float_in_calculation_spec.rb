# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/decimal/no_float_in_calculation"

RSpec.describe RuboCop::Cop::Decimal::NoFloatInCalculation, :config do
  it "registers an offense for .to_f" do
    expect_offense(<<~RUBY)
      total.to_f
            ^^^^ Use BigDecimal, not float, in calculation code (AGENTS); .to_f/Float() belong at the display boundary only.
    RUBY
  end

  it "registers an offense for Float()" do
    expect_offense(<<~RUBY)
      Float(total)
      ^^^^^ Use BigDecimal, not float, in calculation code (AGENTS); .to_f/Float() belong at the display boundary only.
    RUBY
  end

  it "accepts BigDecimal conversion" do
    expect_no_offenses(<<~RUBY)
      BigDecimal(total.to_s)
    RUBY
  end
end
