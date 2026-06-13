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

  it "CHIEU-do-tuoi-nguon-input: bumps on meter no_loss toggle (update_column patch)" do
    contact_point = create(:contact_point, :residential, unit: unit)
    meter = create(:meter, contact_point: contact_point, no_loss: false)

    # Toggling no_loss propagates via update_column (bypasses after_commit),
    # so the explicit touch in propagate_no_loss_to_current_period_reading
    # is what bumps inputs_changed_at here.
    expect {
      meter.update!(no_loss: true)
    }.to change { changed_at(zone, period) }
  end

  it "CHIEU-do-tuoi-nguon-input: bumps on non_establishment personnel_count update (update_column patch)" do
    contact_point = create(:contact_point, :non_establishment, zone: zone, personnel_count: 5)

    # Updating personnel_count propagates to the snapshot via update_column
    # (bypasses after_commit), so the explicit touch in
    # propagate_personnel_count_to_current_snapshot is what bumps here.
    expect {
      contact_point.update!(personnel_count: 7)
    }.to change { changed_at(zone, period) }
  end

  it "CHIEU-do-tuoi-nguon-input: bumps on personnel_entry update" do
    contact_point = create(:contact_point, :residential, unit: unit)
    personnel_entry = create(:personnel_entry, contact_point: contact_point, period: period)

    expect {
      personnel_entry.update!(count: personnel_entry.count + 1)
    }.to change { changed_at(zone, period) }
  end
end
