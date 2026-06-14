require "rails_helper"

RSpec.describe "Billing freshness indicator", type: :request do
  let(:period) { Period.current || create(:period, closed: false) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }
  let!(:meter) { create(:meter, contact_point: contact_point) }
  let!(:meter_reading) do
    create(:meter_reading, meter: meter, period: period, reading_start: 0, reading_end: 100)
  end
  before { sign_in sa }

  def first_reading
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
  end

  it "CHIEU-do-tuoi-sau-tinh-con-dung: no stale banner right after recalculation" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-stale-sau-sua: shows stale banner after an input edit post-calculation" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    first_reading.update!(reading_end: 123)
    get billing_path(period_id: period.id)
    expect(response.body).to include("freshness-stale")
    expect(response.body).to include(zone.name)
  end

  it "CHIEU-do-tuoi-ky-dong: no stale banner when viewing a closed period" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    first_reading.update!(reading_end: 5)
    period.update!(closed: true)
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-chua-tinh: no stale banner for an open period never calculated" do
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-recalc-het-stale: recalculating via the real action clears stale" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    first_reading.update!(reading_end: 123)
    get billing_path(period_id: period.id)
    expect(response.body).to include("freshness-stale")
    post recalculate_billing_path(period_id: period.id)
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end
end
