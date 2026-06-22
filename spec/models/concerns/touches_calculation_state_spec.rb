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

  it "CHIEU-do-tuoi-bump-khi-xoa: discard makes the zone stale (destroy_all path)" do
    contact_point = create(:contact_point, :residential, unit: unit)
    create(:meter, contact_point: contact_point)
    # Establish a calculated baseline in the past so a later input bump is strictly greater.
    baseline = 1.minute.ago
    CalculationState.mark_calculated!(zone_id: zone.id, period_id: period.id, at: baseline)

    # Discard hard-deletes current-period input rows via destroy_all, which fires
    # TouchesCalculationState#after_commit and bumps inputs_changed_at.
    contact_point.discard

    state = CalculationState.find_by(zone_id: zone.id, period_id: period.id)
    expect(state.inputs_changed_at).to be_present
    expect(state.inputs_changed_at).to be > state.last_calculated_at

    entry = CalculationFreshness.new(period: period, zones: Zone.where(id: zone.id)).call.first
    expect(entry.status).to eq(:stale)
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

  it "skips bump when zone_id is nil in calculation_state_targets" do
    # MeterReading with no meter => zone_id resolves to nil
    reading = MeterReading.new(reading_start: 0, period: period)
    expect(CalculationState).not_to receive(:touch_inputs!)
    # Fire the callback directly since the record is unsaved
    reading.send(:bump_calculation_state)
  end

  it "skips bump when period_id is nil in calculation_state_targets" do
    reading = MeterReading.new(reading_start: 0)
    expect(CalculationState).not_to receive(:touch_inputs!)
    reading.send(:bump_calculation_state)
  end

  it "CHIEU-do-tuoi-nguon-input: bumps on personnel_entry update" do
    contact_point = create(:contact_point, :residential, unit: unit)
    personnel_entry = create(:personnel_entry, contact_point: contact_point, period: period)

    expect {
      personnel_entry.update!(count: personnel_entry.count + 1)
    }.to change { changed_at(zone, period) }
  end
end
