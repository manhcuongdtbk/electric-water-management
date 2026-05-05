namespace :data do
  desc "Import February 2026 data AND run CalculationEngine for all units"
  task seed_demo: :environment do
    Rake::Task["data:import_feb_2026"].invoke

    period = MonthlyPeriod.find_by(month: 2, year: 2026)
    if period
      Organization.where(level: :unit).find_each do |org|
        results = CalculationEngine.new(organization: org, monthly_period: period).call
        puts "CalculationEngine ran for #{org.name} — #{results.size} calculations"
      end
    else
      puts "WARNING: MonthlyPeriod 02/2026 not found after import"
    end
  end

  desc "Import February 2026 real data for demo (Sư đoàn bộ). Requires `db:seed` first."
  task import_feb_2026: :environment do
    unless Organization.exists?(code: "SDB")
      abort "SDB organization missing — run `bin/rails db:seed` first."
    end

    result = ImportFeb2026Service.new.call

    puts "=" * 60
    puts "Import completed — period: #{result.period.label}, org: #{result.organization.name}"
    puts "Contact points:    #{result.contact_points_count}"
    puts "Meters:            #{result.meters_count}"
    puts "Meter readings:    #{result.readings_count}"
    puts "Personnel:         #{result.personnel_count}"
    puts "Other deductions:  #{result.other_deductions_count}"
    puts "Pump stations:     #{result.pump_stations_count}"
    puts "Warnings:          #{result.warnings.count}"
    result.warnings.each { |w| puts "  - #{w}" }
    puts "=" * 60
  end
end
