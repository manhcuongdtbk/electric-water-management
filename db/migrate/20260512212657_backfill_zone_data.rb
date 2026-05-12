class BackfillZoneData < ActiveRecord::Migration[8.1]
  class MigrationZone < ActiveRecord::Base
    self.table_name = "zones"
  end

  class MigrationMainMeter < ActiveRecord::Base
    self.table_name = "main_meters"
  end

  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  class MigrationPumpStation < ActiveRecord::Base
    self.table_name = "pump_stations"
  end

  def up
    # Step 1: One zone per existing MainMeter. Manager = first org sharing the meter.
    MigrationMainMeter.find_each do |mm|
      manager_id = MigrationOrganization
                     .where(main_meter_id: mm.id)
                     .order(:position)
                     .limit(1)
                     .pick(:id)

      zone = create_zone(mm.name, manager_id)

      mm.update!(zone_id: zone.id)

      org_ids = MigrationOrganization.where(main_meter_id: mm.id).pluck(:id)
      MigrationOrganization.where(id: org_ids).update_all(zone_id: zone.id)
      MigrationPumpStation.where(organization_id: org_ids).update_all(zone_id: zone.id)
    end

    # Step 2: Solo zone for each unit-level org without a MainMeter.
    # Pre-existing setup may have units that haven't been linked to a meter yet —
    # those need a placeholder zone so the unit's manager-org reference is preserved.
    MigrationOrganization.where(level: 2, zone_id: nil).find_each do |unit|
      zone = create_zone(orphan_zone_name(unit.name), unit.id)
      unit.update!(zone_id: zone.id)
    end

    # Step 3: Solo zone for each pump station still without one. Happens when a
    # pump station is owned by a division-level org (no zone path) or by a unit
    # whose own zone wasn't resolved above. Manager left NULL — admin sets later.
    MigrationPumpStation.where(zone_id: nil).find_each do |ps|
      zone = create_zone(orphan_zone_name(ps.name), nil)
      ps.update!(zone_id: zone.id)
    end

    orphans_mm = MigrationMainMeter.where(zone_id: nil).count
    raise "MainMeter records without zone_id: #{orphans_mm}" if orphans_mm.positive?

    orphans_org = MigrationOrganization.where(level: 2, zone_id: nil).count
    raise "Unit-level Organization records without zone_id: #{orphans_org}" if orphans_org.positive?

    orphans_ps = MigrationPumpStation.where(zone_id: nil).count
    raise "PumpStation records without zone_id: #{orphans_ps}" if orphans_ps.positive?
  end

  def down
    MigrationPumpStation.update_all(zone_id: nil)
    MigrationOrganization.update_all(zone_id: nil)
    MigrationMainMeter.update_all(zone_id: nil)
    MigrationZone.delete_all
  end

  private

  def create_zone(base_name, manager_id)
    name = base_name
    suffix = 1
    while MigrationZone.exists?(name: name)
      suffix += 1
      name = "#{base_name} (#{suffix})"
    end

    MigrationZone.create!(
      name: name,
      manager_organization_id: manager_id,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  def orphan_zone_name(record_name)
    "Khu vực #{record_name}"
  end
end
