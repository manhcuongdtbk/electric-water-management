# Ghi một dòng log khởi động kèm phiên bản + môi trường để truy vết bản phát hành.
# Phiên bản được đọc trong SystemInfo (lib/system_info.rb) — nguồn sự thật duy nhất.
# Dùng after_initialize để SystemInfo đã sẵn sàng; lấy tên app động (module_parent_name)
# để không hard-code tên app, an toàn khi đổi tên sau này.
Rails.application.config.after_initialize do
  Rails.logger.info(
    "Booting #{Rails.application.class.module_parent_name} version=#{SystemInfo.version} " \
    "environment=#{SystemInfo.environment_label} rails_env=#{Rails.env}"
  )
end
