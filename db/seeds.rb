# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ============================================================
# Master data — all environments
# ============================================================

division = Organization.find_or_create_by!(code: "SD") do |org|
  org.name     = "Sư đoàn"
  org.level    = :division
  org.position = 0
end

units = [
  { code: "SDB",   name: "Sư đoàn bộ",    position: 1 },
  { code: "TR101", name: "Trung đoàn 101", position: 2 },
  { code: "TR18",  name: "Trung đoàn 18",  position: 3 },
  { code: "TR95",  name: "Trung đoàn 95",  position: 4 },
  { code: "TD14",  name: "Tiểu đoàn 14",   position: 5 },
  { code: "TD15",  name: "Tiểu đoàn 15",   position: 6 },
  { code: "TD16",  name: "Tiểu đoàn 16",   position: 7 },
  { code: "TD17",  name: "Tiểu đoàn 17",   position: 8 },
  { code: "TD18",  name: "Tiểu đoàn 18",   position: 9 },
  { code: "TD24",  name: "Tiểu đoàn 24",   position: 10 },
  { code: "TD25",  name: "Tiểu đoàn 25",   position: 11 },
  { code: "DH26",  name: "Đại đội 26",     position: 12 },
  { code: "DH29",  name: "Đại đội 29",     position: 13 }
]

units.each do |attrs|
  Organization.find_or_create_by!(code: attrs[:code]) do |org|
    org.name      = attrs[:name]
    org.level     = :unit
    org.parent    = division
    org.position  = attrs[:position]
  end
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
# Demo/production users — all environments except test
# Dev users — all password: admin123
# Seed idempotent: rails db:seed restores all users even when DB already has data
# ============================================================

unless Rails.env.test?
  sdb  = Organization.find_by!(code: "SDB")
  tr101 = Organization.find_by!(code: "TR101")

  dev_users = [
    { email: "admin@example.com",        full_name: "Quản trị viên",      role: :admin_level1, org: division },
    { email: "test_admin1@example.com",  full_name: "Quản trị viên 2",    role: :admin_level1, org: division },
    { email: "admin_unit@example.com",   full_name: "Quản trị đơn vị",    role: :admin_unit,   org: sdb },
    { email: "admin_unit_a@example.com", full_name: "Quản trị đơn vị A",  role: :admin_unit,   org: tr101 },
    { email: "commander@example.com",    full_name: "Chỉ huy",            role: :commander,    org: sdb },
    { email: "commander_a@example.com",  full_name: "Chỉ huy A",          role: :commander,    org: tr101 },
    { email: "tech@example.com",         full_name: "Kỹ thuật",           role: :tech,         org: division },
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

  puts "Users: #{User.count} records"

  # Test accounts for development
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
