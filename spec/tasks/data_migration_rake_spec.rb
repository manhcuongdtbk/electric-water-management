require "rails_helper"
require "rake"

RSpec.describe "data:backfill_main_meters rake task", type: :task do
  let(:task_name) { "data:backfill_main_meters" }

  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task[task_name].reenable
  end

  let(:division) { create(:organization, :division) }
  let(:unit_a)   { create(:organization, :unit, parent: division, code: "U-A", name: "Unit A") }
  let(:unit_b)   { create(:organization, :unit, parent: division, code: "U-B", name: "Unit B") }
  let(:period_1) { create(:monthly_period, year: 2026, month: 1) }
  let(:period_2) { create(:monthly_period, year: 2026, month: 2) }

  it "creates one MainMeter per org with a supply value, links the org, and copies the supply to a reading" do
    create(:unit_config, organization: unit_a, monthly_period: period_1, electricity_supply_kw: 1000)
    create(:unit_config, organization: unit_a, monthly_period: period_2, electricity_supply_kw: 1200)

    expect { Rake::Task[task_name].invoke }
      .to change(MainMeter, :count).by(1)
      .and change(MainMeterReading, :count).by(2)

    mm = MainMeter.find_by!(code: "MM-U-A")
    expect(unit_a.reload.main_meter_id).to eq(mm.id)
    expect(mm.main_meter_readings.find_by(monthly_period: period_1).electricity_supply_kw).to eq(1000)
    expect(mm.main_meter_readings.find_by(monthly_period: period_2).electricity_supply_kw).to eq(1200)
  end

  it "skips orgs without any supply value" do
    create(:unit_config, organization: unit_b, monthly_period: period_1, electricity_supply_kw: nil)

    expect { Rake::Task[task_name].invoke }.not_to change(MainMeter, :count)
    expect(unit_b.reload.main_meter_id).to be_nil
  end

  it "is idempotent: running twice does not duplicate MainMeters or readings" do
    create(:unit_config, organization: unit_a, monthly_period: period_1, electricity_supply_kw: 1000)
    Rake::Task[task_name].invoke

    Rake::Task[task_name].reenable
    expect { Rake::Task[task_name].invoke }
      .to change(MainMeter, :count).by(0)
      .and change(MainMeterReading, :count).by(0)
  end

  it "preserves an org's existing main_meter (does not overwrite link or duplicate)" do
    existing_mm = create(:main_meter, name: "Pre-set zone", code: "MM-PRE")
    unit_a.update!(main_meter: existing_mm)
    create(:unit_config, organization: unit_a, monthly_period: period_1, electricity_supply_kw: 999)

    expect { Rake::Task[task_name].invoke }
      .to change(MainMeter, :count).by(0)
      .and change(MainMeterReading, :count).by(1)

    expect(unit_a.reload.main_meter_id).to eq(existing_mm.id)
    expect(existing_mm.main_meter_readings.find_by(monthly_period: period_1).electricity_supply_kw).to eq(999)
  end
end
