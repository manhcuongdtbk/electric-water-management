require "rails_helper"

RSpec.describe "Billing Excel export guard", type: :request do
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
    meter_reading.reload.update!(reading_end: 77)
  end

  it "CHIEU-do-tuoi-excel-block: redirects with alert when exporting stale data without acknowledgement" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).to include(I18n.t("billing.export.stale_blocked"))
  end

  it "allows export of fresh data" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("spreadsheetml")
  end

  it "allows export of stale data when acknowledged" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
  end

  it "CHIEU-do-tuoi-excel-stamp: stamps a warning into the file when exporting acknowledged stale data" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
    require "zip"
    shared = ""
    Zip::File.open_buffer(StringIO.new(response.body)) do |zip|
      entry = zip.find_entry("xl/sharedStrings.xml")
      shared = entry.get_input_stream.read if entry
    end
    expect(shared).to include("CẢNH BÁO")
  end
end
