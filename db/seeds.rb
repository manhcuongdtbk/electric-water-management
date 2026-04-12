# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ============================================================
# Organizations
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

# ============================================================
# Rank quotas (7 groups, effective from 2024-01-01)
# ============================================================

rank_names = {
  1 => "Sĩ quan cao cấp",
  2 => "Sĩ quan trung cấp",
  3 => "Sĩ quan cơ sở",
  4 => "Hạ sĩ quan - Binh sĩ",
  5 => "Quân nhân chuyên nghiệp",
  6 => "Công nhân viên quốc phòng",
  7 => "Học viên"
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
# Admin level 1 user
# ============================================================

User.find_or_create_by!(email: "admin@example.com") do |u|
  u.full_name             = "Quản trị viên"
  u.password              = "admin123"
  u.password_confirmation = "admin123"
  u.role                  = :admin_level1
  u.organization          = division
  u.force_password_change = false
end

puts "Users: #{User.count} records"
puts "Seed completed successfully."
