namespace :data do
  desc "Backfill MainMeter + MainMeterReading from existing unit_configs.electricity_supply_kw. " \
       "Idempotent. Creates one MainMeter per org with a supply value, copies the supply over " \
       "to a MainMeterReading per period, and links the org. Admin_level1 must then merge " \
       "MainMeters in the UI for shared zones (e.g. Cơ quan SDB + TĐ18 + ĐĐ20-23 → one zone)."
  task backfill_main_meters: :environment do
    created_meters   = 0
    created_readings = 0
    linked_orgs      = 0

    UnitConfig.where.not(electricity_supply_kw: nil)
              .includes(:organization, :monthly_period)
              .group_by(&:organization).each do |org, configs|
      next if org.nil?

      main_meter = if org.main_meter_id.present?
        MainMeter.find(org.main_meter_id)
      else
        mm = MainMeter.create!(
          name: "ĐH tổng — #{org.name}",
          code: "MM-#{org.code}"
        )
        org.update!(main_meter_id: mm.id)
        created_meters += 1
        linked_orgs    += 1
        mm
      end

      configs.each do |cfg|
        reading = MainMeterReading.find_or_initialize_by(
          main_meter: main_meter,
          monthly_period: cfg.monthly_period
        )
        next if reading.persisted?

        reading.electricity_supply_kw = cfg.electricity_supply_kw
        reading.save!
        created_readings += 1
      end
    end

    puts "Backfill done. MainMeters created: #{created_meters}, organizations linked: " \
         "#{linked_orgs}, MainMeterReadings created: #{created_readings}."
    puts "Next step: admin_level1 should merge MainMeters in /main_meters UI for any " \
         "organizations that share a physical meter (e.g. Cơ quan SDB + TĐ18 + ĐĐ20-23)."
  end
end
