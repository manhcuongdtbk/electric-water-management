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

# Rank quotas — names per XAC_NHAN_NGHIEP_VU_v5
rank_names = {
  1 => "Chỉ huy sư đoàn và tương đương; quân hàm cao nhất là Đại tá",
  2 => "Chỉ huy lữ đoàn, trung đoàn và tương đương; quân hàm cao nhất là Thượng tá",
  3 => "Chỉ huy tiểu đoàn và tương đương; quân hàm cao nhất là Trung tá, Thiếu tá",
  4 => "Chỉ huy đại đội, trung đội và tương đương; quân hàm là cấp Úy",
  5 => "Cơ quan sư đoàn, lữ đoàn, trung đoàn và tương đương",
  6 => "Tiểu đoàn, đại đội và tương đương",
  7 => "Hạ sĩ quan, binh sĩ; thiếu sinh quân; học sinh năng khiếu"
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
# Development-only data — NOT for production
# ============================================================

if Rails.env.development?
  User.find_or_create_by!(email: "admin@example.com") do |u|
    u.full_name             = "Quản trị viên"
    u.password              = "admin123"
    u.password_confirmation = "admin123"
    u.role                  = :admin_level1
    u.organization          = division
    u.force_password_change = false
  end

  puts "Users: #{User.count} records (development only)"
end

puts "Seed completed successfully."
