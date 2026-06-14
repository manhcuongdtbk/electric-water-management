require "rails_helper"

RSpec.describe "Stale Excel export confirmation", type: :system do
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

  it "CHIEU-do-tuoi-excel-confirm: asks for confirmation before exporting stale data" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    meter_reading.reload.update!(reading_end: 88)

    visit billing_path(period_id: period.id)
    expect(page).to have_css('[data-testid="freshness-stale"]')

    dismiss_confirm do
      click_link "Xuất Excel"
    end

    # Dismissing the confirm cancels the navigation, so we stay on billing.
    expect(page).to have_current_path(/billing/)
  end
end
