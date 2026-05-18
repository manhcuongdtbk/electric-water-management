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

puts "Đã tạo #{User.count} tài khoản mặc định"
