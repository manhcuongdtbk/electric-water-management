require "rails_helper"

RSpec.describe TouchesCalculationState do
  def changed_at(zone, period)
    CalculationState.find_by(zone_id: zone.id, period_id: period.id)&.inputs_changed_at
  end

  let!(:period) { Period.current || create(:period, closed: false) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }

  it "CHIEU-do-tuoi-nguon-input: bumps on meter_reading update" do
    contact_point = create(:contact_point, :residential, unit: unit)
    meter = create(:meter, contact_point: contact_point)
    # The meter's after_create callback already made the current-period reading.
    reading = meter.meter_readings.find_by(period: period)

    expect {
      reading.update!(reading_end: 250)
    }.to change { changed_at(zone, period) }
  end

  it "CHIEU-do-tuoi-bump-khi-xoa: bumps on meter_reading destroy" do
    contact_point = create(:contact_point, :residential, unit: unit)
    meter = create(:meter, contact_point: contact_point)
    reading = meter.meter_readings.find_by(period: period)

    expect {
      reading.destroy!
    }.to change { changed_at(zone, period) }
  end

  it "CHIEU-do-tuoi-nguon-input: bumps on pump_allocation create" do
    expect {
      create(:pump_allocation, zone: zone, period: period)
    }.to change { changed_at(zone, period) }
  end

  it "CHIEU-do-tuoi-nguon-input: bumps on unit_config update" do
    # Creating the unit auto-creates the current-period unit_config; fetch it.
    unit_config = unit.unit_configs.find_by(period: period)

    expect {
      unit_config.update!(unit_public_rate: 25)
    }.to change { changed_at(zone, period) }
  end
end
