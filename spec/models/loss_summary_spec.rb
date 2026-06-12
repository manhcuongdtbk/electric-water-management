require "rails_helper"

RSpec.describe LossSummary do
  let(:sample) { setup_zone_one_full_sample }

  it "thuộc về zone và period" do
    ls = LossSummary.new(zone: sample.zone, period: sample.period,
                         a: BigDecimal("1990"), b: BigDecimal("1930"), c: BigDecimal("60"))
    expect(ls).to be_valid
  end

  it "unique theo (zone_id, period_id)" do
    LossSummary.create!(zone: sample.zone, period: sample.period,
                        a: BigDecimal("1"), b: BigDecimal("1"), c: BigDecimal("0"))
    dup = LossSummary.new(zone: sample.zone, period: sample.period,
                          a: BigDecimal("2"), b: BigDecimal("2"), c: BigDecimal("0"))
    expect(dup).not_to be_valid
  end
end
