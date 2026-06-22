# Script tạo dữ liệu mẫu cho chụp ảnh hướng dẫn sử dụng
# Chạy: docker compose -f compose.dev.yml exec app bin/rails runner tmp/screenshot_seed.rb

puts "=== Tắt force_password_change cho 2 tài khoản mặc định ==="
User.where(default_account: true).update_all(force_password_change: false)

puts "=== Bước 1: Mở kỳ đầu tiên (tháng 4/2026) ==="
service = PeriodService.new
result = service.open_new_period(year: 2026, month: 4, unit_price: BigDecimal("2336.4"))
period_1 = result.period
period_1.update_column(:pump_allocation_per_station, false)
ranks_1 = Rank.where(period: period_1).order(:position).to_a
puts "  Kỳ #{period_1.year}/#{period_1.month} đã mở (#{ranks_1.size} nhóm cấp bậc)"

puts "=== Bước 2: Tạo 2 khu vực ==="
zone_1 = Zone.create!(name: "Khu vực 1", main_meters_attributes: [{ name: "Công tơ tổng Khu vực 1" }])
zone_2 = Zone.create!(name: "Khu vực 2", main_meters_attributes: [{ name: "Công tơ tổng Khu vực 2" }])

puts "=== Bước 3: Tạo 4 đơn vị ==="
unit_td95 = Unit.create!(name: "Trung đoàn 95", zone: zone_1)
unit_td14 = Unit.create!(name: "Tiểu đoàn 14", zone: zone_1)
unit_td18 = Unit.create!(name: "Trung đoàn 18", zone: zone_2)
unit_d3   = Unit.create!(name: "Đại đội 3", zone: zone_2)

puts "=== Bước 4: Tạo tài khoản ==="
pw = "Abc@1234"
opt = { force_password_change: false }

User.create!(username: "quanTriTD95", password: pw, password_confirmation: pw,
  display_name: "Nguyễn Văn Hùng", role: :unit_admin, unit: unit_td95, **opt)
User.create!(username: "quanTriTD14", password: pw, password_confirmation: pw,
  display_name: "Trần Minh Đức", role: :unit_admin, unit: unit_td14, **opt)
User.create!(username: "quanTriTD18", password: pw, password_confirmation: pw,
  display_name: "Lê Quốc Bảo", role: :unit_admin, unit: unit_td18, **opt)
User.create!(username: "chiHuyTD95", password: pw, password_confirmation: pw,
  display_name: "Phạm Đức Trung", role: :commander, unit: unit_td95, **opt)
User.create!(username: "chiHuyTD14", password: pw, password_confirmation: pw,
  display_name: "Hoàng Anh Tuấn", role: :commander, unit: unit_td14, **opt)
User.create!(username: "chiHuySuDoan", password: pw, password_confirmation: pw,
  display_name: "Trần Quốc Việt", role: :division_commander, **opt)

puts "=== Bước 5: Tạo khối và nhóm (Trung đoàn 95) ==="
block_ptm = Block.create!(name: "Phòng Tham mưu", unit: unit_td95)
block_pct = Block.create!(name: "Phòng Chính trị", unit: unit_td95)
group_bth = Group.create!(name: "Ban Tác huấn", unit: unit_td95, block: block_ptm)
group_txe = Group.create!(name: "Tổ xe", unit: unit_td95)

puts "=== Bước 6: Helper tạo đầu mối ==="

# Tạo hash { rank_id => count } từ { position => count }
def personnel_hash(ranks, position_counts)
  result = {}
  position_counts.each do |pos, count|
    rank = ranks.find { |r| r.position == pos }
    result[rank.id] = count if rank
  end
  result
end

# Tạo đầu mối sinh hoạt
def make_residential(name:, unit: nil, zone: nil, block: nil, group: nil, meter_name:, personnel_hash:, no_loss: false)
  ContactPoint.create!(
    name: name, contact_point_type: :residential,
    unit_id: unit&.id, zone_id: zone&.id,
    block_id: block&.id, group_id: group&.id,
    initial_personnel_counts: personnel_hash,
    meters_attributes: [{ name: meter_name, no_loss: no_loss }]
  )
end

# Tạo đầu mối công cộng
def make_public(name:, unit: nil, zone: nil, meter_name:, no_loss: false)
  ContactPoint.create!(
    name: name, contact_point_type: :public,
    unit_id: unit&.id, zone_id: zone&.id,
    meters_attributes: [{ name: meter_name, no_loss: no_loss }]
  )
end

# Tạo đầu mối bơm nước
def make_water_pump(name:, zone:, meter_name:)
  ContactPoint.create!(
    name: name, contact_point_type: :water_pump,
    zone: zone,
    meters_attributes: [{ name: meter_name }]
  )
end

puts "=== Bước 7: Đầu mối sinh hoạt — Trung đoàn 95 ==="
# Phòng Tham mưu > Ban Tác huấn
make_residential(name: "Trưởng ban và Quý", unit: unit_td95, block: block_ptm, group: group_bth,
  meter_name: "CT-TM01", personnel_hash: personnel_hash(ranks_1, { 3 => 1, 5 => 1 }))
make_residential(name: "Tuấn, Nam, Công", unit: unit_td95, block: block_ptm, group: group_bth,
  meter_name: "CT-TM02", personnel_hash: personnel_hash(ranks_1, { 5 => 2, 7 => 1 }))
# Phòng Tham mưu trực tiếp
make_residential(name: "Văn thư", unit: unit_td95, block: block_ptm,
  meter_name: "CT-TM03", personnel_hash: personnel_hash(ranks_1, { 6 => 1, 7 => 2 }))
make_residential(name: "Lái xe", unit: unit_td95, block: block_ptm,
  meter_name: "CT-TM04", personnel_hash: personnel_hash(ranks_1, { 7 => 3 }))
# Phòng Chính trị
make_residential(name: "Chủ nhiệm và Hòa", unit: unit_td95, block: block_pct,
  meter_name: "CT-CT01", personnel_hash: personnel_hash(ranks_1, { 3 => 1, 5 => 1 }))
make_residential(name: "Tuyên huấn", unit: unit_td95, block: block_pct,
  meter_name: "CT-CT02", personnel_hash: personnel_hash(ranks_1, { 5 => 1, 6 => 2 }))
# Tổ xe (nhóm trực tiếp, không khối)
make_residential(name: "Nhà ở", unit: unit_td95, group: group_txe,
  meter_name: "CT-TX01", personnel_hash: personnel_hash(ranks_1, { 6 => 2, 7 => 4 }))
make_residential(name: "Bếp", unit: unit_td95, group: group_txe,
  meter_name: "CT-TX02", personnel_hash: personnel_hash(ranks_1, { 7 => 3 }))
# Trực tiếp đơn vị
make_residential(name: "Kho vật tư", unit: unit_td95,
  meter_name: "CT-KV01", personnel_hash: personnel_hash(ranks_1, { 6 => 1, 7 => 2 }))

puts "=== Bước 8: Đầu mối sinh hoạt — Tiểu đoàn 14 ==="
make_residential(name: "Đại đội 1", unit: unit_td14,
  meter_name: "CT-D14-01", personnel_hash: personnel_hash(ranks_1, { 4 => 2, 6 => 5, 7 => 30 }))
make_residential(name: "Đại đội 2", unit: unit_td14,
  meter_name: "CT-D14-02", personnel_hash: personnel_hash(ranks_1, { 4 => 2, 6 => 4, 7 => 28 }))

puts "=== Bước 9: Đầu mối sinh hoạt — Trung đoàn 18 ==="
make_residential(name: "Ban chỉ huy", unit: unit_td18,
  meter_name: "CT-TD18-01", personnel_hash: personnel_hash(ranks_1, { 2 => 1, 3 => 2, 5 => 3 }))
make_residential(name: "Hậu cần", unit: unit_td18,
  meter_name: "CT-TD18-02", personnel_hash: personnel_hash(ranks_1, { 5 => 2, 6 => 3, 7 => 5 }))

puts "=== Bước 10: Đầu mối sinh hoạt — Đại đội 3 ==="
make_residential(name: "Trung đội 1", unit: unit_d3,
  meter_name: "CT-D3-01", personnel_hash: personnel_hash(ranks_1, { 4 => 1, 7 => 12 }))

puts "=== Bước 11: Đầu mối sinh hoạt thuộc khu vực ==="
make_residential(name: "Chỉ huy khu vực", zone: zone_1,
  meter_name: "CT-CHKV1", personnel_hash: personnel_hash(ranks_1, { 1 => 1, 2 => 1 }))
make_residential(name: "Phó chỉ huy khu vực", zone: zone_1,
  meter_name: "CT-PCHKV1", personnel_hash: personnel_hash(ranks_1, { 2 => 1, 3 => 1 }))

puts "=== Bước 12: Đầu mối công cộng ==="
make_public(name: "Đèn đường", unit: unit_td95, meter_name: "CT-DD01")
make_public(name: "Hội trường", unit: unit_td95, meter_name: "CT-HT01")
make_public(name: "Nhà ăn tập thể", zone: zone_1, meter_name: "CT-NATT01")
make_public(name: "Đèn sân", unit: unit_td18, meter_name: "CT-DS01")

puts "=== Bước 13: Đầu mối bơm nước ==="
make_water_pump(name: "Trạm bơm 1", zone: zone_1, meter_name: "CT-BN01")
make_water_pump(name: "Trạm bơm 2", zone: zone_1, meter_name: "CT-BN02")
make_water_pump(name: "Trạm bơm chính", zone: zone_2, meter_name: "CT-BN03")

puts "=== Bước 14: Đầu mối ngoài biên chế ==="
ne1 = ContactPoint.create!(name: "Thợ xây công trình", contact_point_type: :non_establishment, zone: zone_1, personnel_count: 15)
ne2 = ContactPoint.create!(name: "Thợ điện hợp đồng", contact_point_type: :non_establishment, zone: zone_2, personnel_count: 8)

puts "=== Bước 15: Cấu hình đơn vị ==="
UnitConfig.find_by(unit: unit_td95, period: period_1)&.update!(unit_public_rate: BigDecimal("3"))
UnitConfig.find_by(unit: unit_td18, period: period_1)&.update!(unit_public_rate: BigDecimal("2"))

cp_nha_o = ContactPoint.find_by(name: "Nhà ở")
cp_kho = ContactPoint.find_by(name: "Kho vật tư")
OtherDeduction.find_by(contact_point: cp_nha_o, period: period_1)&.update!(other_type: :coefficient, other_value: BigDecimal("2.5"))
OtherDeduction.find_by(contact_point: cp_kho, period: period_1)&.update!(other_type: :fixed, other_value: BigDecimal("-15"))

cp_bep = ContactPoint.find_by(name: "Bếp")
OtherDeduction.find_by(contact_point: cp_bep, period: period_1)&.update!(other_type: :unit_coefficient, other_value: BigDecimal("-2"))

puts "=== Bước 16: Phân bổ bơm nước ==="
cp_chkv = ContactPoint.find_by(name: "Chỉ huy khu vực")

# Khu vực 1
PumpAllocation.create!(zone: zone_1, period: period_1, contact_point: cp_chkv, fixed_percentage: BigDecimal("20"), coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_1, unit: unit_td95, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_1, unit: unit_td14, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_1, contact_point: ne1, coefficient: BigDecimal("0.5"))

# Khu vực 2
PumpAllocation.create!(zone: zone_2, period: period_1, unit: unit_td18, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_2, period: period_1, unit: unit_d3, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_2, period: period_1, contact_point: ne2, coefficient: BigDecimal("0.5"))

puts "=== Bước 17: Nhập chỉ số công tơ (kỳ 1) ==="
meter_data = {
  "CT-TM01" => 150, "CT-TM02" => 200, "CT-TM03" => 80, "CT-TM04" => 120,
  "CT-CT01" => 180, "CT-CT02" => 160,
  "CT-TX01" => 250, "CT-TX02" => 90,
  "CT-KV01" => 110,
  "CT-D14-01" => 800, "CT-D14-02" => 750,
  "CT-TD18-01" => 350, "CT-TD18-02" => 280,
  "CT-D3-01" => 400,
  "CT-CHKV1" => 500, "CT-PCHKV1" => 420,
  "CT-DD01" => 60, "CT-HT01" => 100, "CT-NATT01" => 85, "CT-DS01" => 45,
  "CT-BN01" => 300, "CT-BN02" => 250, "CT-BN03" => 400
}

meter_data.each do |meter_name, reading_end|
  meter = Meter.find_by(name: meter_name)
  next unless meter
  reading = MeterReading.find_by(meter: meter, period: period_1)
  reading&.update!(reading_end: BigDecimal(reading_end.to_s))
end

puts "=== Bước 18: Nhập số điện lực (công tơ tổng) ==="
MainMeterReading.create!(main_meter: zone_1.main_meters.first, period: period_1, usage: BigDecimal("3200"))
MainMeterReading.create!(main_meter: zone_2.main_meters.first, period: period_1, usage: BigDecimal("1600"))

puts "=== Bước 19: Tính toán kỳ 1 ==="
[zone_1, zone_2].each do |zone|
  CalculationOrchestrator.new(zone: zone, period: period_1).call
end
puts "  Kết quả: #{Calculation.where(period: period_1).count} bản ghi"

puts "=== Bước 20: Đóng kỳ 1 ==="
service.close_period(period_1)

puts "=== Bước 21: Mở kỳ 2 (tháng 5/2026) ==="
result2 = service.open_new_period(unit_price: BigDecimal("2336.4"))
period_2 = result2.period
puts "  Kỳ #{period_2.year}/#{period_2.month} đã mở"

puts "=== Bước 21b: Phân bổ bơm theo trạm cho kỳ 2 (TN2, mặc định per-station) ==="
PumpAllocation.where(period: period_2).destroy_all

pump_station_1 = ContactPoint.find_by(name: "Trạm bơm 1")
pump_station_2 = ContactPoint.find_by(name: "Trạm bơm 2")

PumpAllocation.create!(zone: zone_1, period: period_2, pump_contact_point: pump_station_1,
  unit: unit_td95, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_2, pump_contact_point: pump_station_1,
  unit: unit_td14, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_2, pump_contact_point: pump_station_1,
  contact_point: ne1, coefficient: BigDecimal("0.5"))

cp_pchkv = ContactPoint.find_by(name: "Phó chỉ huy khu vực")
PumpAllocation.create!(zone: zone_1, period: period_2, pump_contact_point: pump_station_2,
  contact_point: cp_chkv, fixed_percentage: BigDecimal("30"), coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_1, period: period_2, pump_contact_point: pump_station_2,
  contact_point: cp_pchkv, coefficient: BigDecimal("1"))

pump_station_3 = ContactPoint.find_by(name: "Trạm bơm chính")
PumpAllocation.create!(zone: zone_2, period: period_2, pump_contact_point: pump_station_3,
  unit: unit_td18, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_2, period: period_2, pump_contact_point: pump_station_3,
  unit: unit_d3, coefficient: BigDecimal("1"))
PumpAllocation.create!(zone: zone_2, period: period_2, pump_contact_point: pump_station_3,
  contact_point: ne2, coefficient: BigDecimal("0.5"))

puts "  Kỳ 2 per-station: KV1 Trạm 1 (3), Trạm 2 (2); KV2 Trạm chính (3)"

puts "=== Bước 21c: Kế thừa unit_coefficient cho kỳ 2 ==="
cp_bep_2 = ContactPoint.find_by(name: "Bếp")
OtherDeduction.find_by(contact_point: cp_bep_2, period: period_2)&.update!(other_type: :unit_coefficient, other_value: BigDecimal("-2"))
cp_kho_2 = ContactPoint.find_by(name: "Kho vật tư")
OtherDeduction.find_by(contact_point: cp_kho_2, period: period_2)&.update!(other_type: :fixed, other_value: BigDecimal("-15"))
cp_nha_o_2 = ContactPoint.find_by(name: "Nhà ở")
OtherDeduction.find_by(contact_point: cp_nha_o_2, period: period_2)&.update!(other_type: :coefficient, other_value: BigDecimal("2.5"))

puts "=== Bước 22: Nhập chỉ số công tơ (kỳ 2) ==="
meter_data_2 = {
  "CT-TM01" => 310, "CT-TM02" => 420, "CT-TM03" => 165, "CT-TM04" => 245,
  "CT-CT01" => 370, "CT-CT02" => 330,
  "CT-TX01" => 520, "CT-TX02" => 185,
  "CT-KV01" => 225,
  "CT-D14-01" => 1650, "CT-D14-02" => 1530,
  "CT-TD18-01" => 720, "CT-TD18-02" => 575,
  "CT-D3-01" => 830,
  "CT-CHKV1" => 1020, "CT-PCHKV1" => 860,
  "CT-DD01" => 125, "CT-HT01" => 210, "CT-NATT01" => 175, "CT-DS01" => 95,
  "CT-BN01" => 620, "CT-BN02" => 510, "CT-BN03" => 820
}

meter_data_2.each do |meter_name, reading_end|
  meter = Meter.find_by(name: meter_name)
  next unless meter
  reading = MeterReading.find_by(meter: meter, period: period_2)
  reading&.update!(reading_end: BigDecimal(reading_end.to_s))
end

puts "=== Bước 23: Nhập số điện lực kỳ 2 ==="
MainMeterReading.create!(main_meter: zone_1.main_meters.first, period: period_2, usage: BigDecimal("3400"))
MainMeterReading.create!(main_meter: zone_2.main_meters.first, period: period_2, usage: BigDecimal("1700"))

puts "=== Bước 24: Tính toán kỳ 2 ==="
[zone_1, zone_2].each do |zone|
  CalculationOrchestrator.new(zone: zone, period: period_2).call
end
puts "  Kết quả: #{Calculation.where(period: period_2).count} bản ghi"

puts ""
puts "=== HOÀN TẤT ==="
puts "  Khu vực: #{Zone.count}"
puts "  Đơn vị: #{Unit.count}"
puts "  Đầu mối: #{ContactPoint.count} (sinh hoạt: #{ContactPoint.type_residential.count}, công cộng: #{ContactPoint.type_public.count}, bơm nước: #{ContactPoint.type_water_pump.count}, ngoài biên chế: #{ContactPoint.type_non_establishment.count})"
puts "  Công tơ: #{Meter.count}"
puts "  Khối: #{Block.count}, Nhóm: #{Group.count}"
puts "  Tài khoản: #{User.count}"
puts "  Kỳ: #{Period.count} (mở: #{Period.where(closed: false).count})"
puts "  Kết quả tính toán: #{Calculation.count}"
puts ""
puts "  Tài khoản đăng nhập (mật khẩu: Abc@1234):"
User.order(:role, :username).each do |u|
  zone_manager = u.unit && Zone.kept.exists?(manager_unit_id: u.unit_id) ? " [quản lý khu vực]" : ""
  puts "    #{u.username} — #{u.display_name} (#{u.role})#{zone_manager}"
end
