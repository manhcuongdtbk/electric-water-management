User.find_or_create_by!(username: "kyThuat") do |user|
  user.password = "Abc@1234"
  user.password_confirmation = "Abc@1234"
  user.display_name = "Kỹ thuật viên"
  user.role = :technician
  user.force_password_change = true
  user.default_account = true
end

User.find_or_create_by!(username: "quanTri") do |user|
  user.password = "Abc@1234"
  user.password_confirmation = "Abc@1234"
  user.display_name = "Quản trị viên hệ thống"
  user.role = :system_admin
  user.force_password_change = true
  user.default_account = true
end

puts "Default accounts created: #{User.count}"
puts "  kyThuat  (technician)    — password: Abc@1234 (force change on first login)"
puts "  quanTri  (system_admin)  — password: Abc@1234 (force change on first login)"
puts ""
puts "System has 5 database roles (7 runtime roles):"
puts "  technician, system_admin, division_commander, unit_admin, commander"
puts "  (unit_admin and commander each split into zone-manager variants at runtime)"
