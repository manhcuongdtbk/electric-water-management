# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ============================================================
# Master data — required in every environment
# ============================================================
#
# Production-essential: 1 division, 7 rank quotas, 1 monthly period for the
# current month, 1 admin_level1 user, 1 tech user. Level-2 units are NOT seeded
# here — admin_level1 creates them through the web UI (/organizations).

division = Organization.find_or_create_by!(name: "Sư đoàn") do |org|
  org.level    = :division
  org.position = 0
end

puts "Organizations: #{Organization.count} records"

# Rank quotas — names per 02_GLOSSARY_v1_3_0 mục 9 (client-approved template 21/04)
rank_names = {
  1 => "Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá",
  2 => "Chỉ huy Trung đoàn; SQ có trần quân hàm là Thượng tá",
  3 => "Chỉ huy tiểu đoàn; SQ có trần quân hàm là Trung tá, Thiếu tá",
  4 => "Chỉ huy đại đội, trung đội; SQ có trần quân hàm là cấp Úy",
  5 => "Cơ quan sư đoàn, trung đoàn",
  6 => "Tiểu đoàn, đại đội",
  7 => "Hạ sĩ quan, binh sĩ"
}

effective_from = Date.new(2024, 1, 1)

RankQuota::STANDARD_QUOTAS.each do |group, quota_kw|
  RankQuota.find_or_create_by!(rank_group: group, effective_from: effective_from) do |rq|
    rq.rank_name = rank_names[group]
    rq.quota_kw  = quota_kw
  end
end

puts "RankQuotas: #{RankQuota.count} records"

# ============================================================
# Production-essential users + current period — every env except test
# ============================================================
#
# Two seeded accounts (admin@example.com, tech@example.com) bootstrap a fresh
# install. Both are created with `force_password_change: true` so the deployer
# must rotate the default password (admin123) on first sign-in.
unless Rails.env.test?
  today = Date.current
  MonthlyPeriod.find_or_create_by!(year: today.year, month: today.month) do |mp|
    mp.unit_price = nil # admin_level1 sets it later via F20
  end

  puts "MonthlyPeriods: #{MonthlyPeriod.count} records"

  essential_users = [
    { email: "admin@example.com", full_name: "Quản trị viên", role: :admin_level1, org: division },
    { email: "tech@example.com",  full_name: "Kỹ thuật",      role: :tech,         org: division }
  ]

  essential_users.each do |attrs|
    user = User.find_or_initialize_by(email: attrs[:email])
    user.full_name = attrs[:full_name]
    user.role      = attrs[:role]
    user.organization = attrs[:org]
    if user.new_record?
      user.password              = "admin123"
      user.password_confirmation = "admin123"
      user.force_password_change = true
    end
    user.save!
  end

  puts "Essential users: #{essential_users.count} records"
end

# ============================================================
# Demo / test accounts — development only (or when explicitly requested)
# ============================================================
#
# These accounts depend on level-2 units that production no longer seeds.
# We materialise the units inside this block so dev / staging keep working.
# Gate: Rails.env.development? OR ENV["SEED_TEST_ACCOUNTS"] == "true".
if Rails.env.development? || ENV["SEED_TEST_ACCOUNTS"] == "true"
  sdb = Organization.find_or_create_by!(name: "Sư đoàn bộ") do |org|
    org.level    = :unit
    org.parent   = division
    org.position = 1
  end

  tr101 = Organization.find_or_create_by!(name: "Trung đoàn 101") do |org|
    org.level    = :unit
    org.parent   = division
    org.position = 2
  end

  dev_users = [
    { email: "test_admin1@example.com",  full_name: "Quản trị viên 2",    role: :admin_level1, org: division },
    { email: "admin_unit@example.com",   full_name: "Quản trị đơn vị",    role: :admin_unit,   org: sdb },
    { email: "admin_unit_a@example.com", full_name: "Quản trị đơn vị A",  role: :admin_unit,   org: tr101 },
    { email: "commander@example.com",    full_name: "Chỉ huy",            role: :commander,    org: sdb },
    { email: "commander_a@example.com",  full_name: "Chỉ huy A",          role: :commander,    org: tr101 },
    { email: "test_adminunit@example.com", full_name: "Quản trị đơn vị B", role: :admin_unit,  org: tr101 }
  ]

  dev_users.each do |attrs|
    user = User.find_or_initialize_by(email: attrs[:email])
    user.full_name             = attrs[:full_name]
    user.password              = "admin123"
    user.password_confirmation = "admin123"
    user.role                  = attrs[:role]
    user.organization          = attrs[:org]
    user.force_password_change = false
    user.save!
  end

  puts "Dev users: #{dev_users.count} records seeded"

  # Test accounts (PR#64) — `cuong` and `thy` smoke-test personas
  test_users = [
    { email: "cuong_admin1@test.local",    full_name: "Cường - QTV cấp 1",    role: :admin_level1, org: division },
    { email: "cuong_unit@test.local",      full_name: "Cường - QTV đơn vị",   role: :admin_unit,   org: sdb },
    { email: "cuong_commander@test.local", full_name: "Cường - Chỉ huy",      role: :commander,    org: sdb },
    { email: "cuong_tech@test.local",      full_name: "Cường - Kỹ thuật",     role: :tech,         org: division },
    { email: "thy_admin1@test.local",      full_name: "Thy - QTV cấp 1",      role: :admin_level1, org: division },
    { email: "thy_unit@test.local",        full_name: "Thy - QTV đơn vị",     role: :admin_unit,   org: tr101 },
    { email: "thy_commander@test.local",   full_name: "Thy - Chỉ huy",        role: :commander,    org: tr101 },
    { email: "thy_tech@test.local",        full_name: "Thy - Kỹ thuật",       role: :tech,         org: division }
  ]

  test_users.each do |attrs|
    user = User.find_or_initialize_by(email: attrs[:email])
    user.full_name             = attrs[:full_name]
    user.password              = "Test1234!"
    user.password_confirmation = "Test1234!"
    user.role                  = attrs[:role]
    user.organization          = attrs[:org]
    user.force_password_change = false
    user.save!
  end

  puts "Test accounts: #{test_users.count} records seeded"
end

puts "Seed completed successfully."
