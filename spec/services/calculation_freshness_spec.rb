require "rails_helper"

RSpec.describe CalculationFreshness do
  let(:period) { create(:period) }
  let(:zone_a) { create(:zone, name: "A") }
  let(:zone_b) { create(:zone, name: "B") }

  it "returns empty array when period is nil (line 12)" do
    result = described_class.new(period: nil, zones: Zone.where(id: zone_a.id)).call
    expect(result).to eq([])
  end

  it "CHIEU-do-tuoi-per-zone: one entry per zone with a state row, sorted by name" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id)
    CalculationState.touch_inputs!(zone_id: zone_b.id, period_id: period.id)
    result = described_class.new(period: period, zones: Zone.where(id: [zone_a.id, zone_b.id]).order(:name)).call
    expect(result.map { |e| e.zone.id }).to eq([zone_a.id, zone_b.id])
    expect(result.map(&:status)).to eq([:fresh, :never_calculated])
  end

  it "CHIEU-do-tuoi-stale-sau-sua: marks stale when inputs changed after calculation" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id, at: 2.minutes.ago)
    CalculationState.touch_inputs!(zone_id: zone_a.id, period_id: period.id, at: Time.current)
    result = described_class.new(period: period, zones: Zone.where(id: zone_a.id)).call
    expect(result.first.status).to eq(:stale)
  end

  it "any_stale? is true when at least one zone is stale" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id, at: 2.minutes.ago)
    CalculationState.touch_inputs!(zone_id: zone_a.id, period_id: period.id, at: Time.current)
    expect(described_class.new(period: period, zones: Zone.where(id: zone_a.id)).any_stale?).to be(true)
  end
end
