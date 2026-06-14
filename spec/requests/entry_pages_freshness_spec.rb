require "rails_helper"

RSpec.describe "Freshness indicator across pages", type: :request do
  let(:period) { Period.current || create(:period, closed: false) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }
  let!(:meter) { create(:meter, contact_point: contact_point) }
  let!(:meter_reading) do
    MeterReading.find_by(meter_id: meter.id, period_id: period.id) ||
      create(:meter_reading, meter: meter, period: period, reading_start: 0, reading_end: 100)
  end

  before { sign_in sa }

  def make_stale!
    CalculationOrchestrator.new(zone: zone, period: period).call
    meter_reading.reload.update!(reading_end: 50)
  end

  it "CHIEU-do-tuoi-5-trang: dashboard shows stale banner" do
    make_stale!
    get dashboard_path
    expect(response.body).to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-5-trang: meter_entries shows stale banner" do
    make_stale!
    get meter_entries_path
    expect(response.body).to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-5-trang: pump_entries shows stale banner" do
    make_stale!
    get pump_entries_path
    expect(response.body).to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-5-trang: electricity_supply shows stale banner" do
    make_stale!
    get electricity_supply_path
    expect(response.body).to include("freshness-stale")
  end
end
