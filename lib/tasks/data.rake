namespace :data do
  desc "Import February 2026 real data for demo (Sư đoàn bộ)"
  task import_feb_2026: :environment do
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
