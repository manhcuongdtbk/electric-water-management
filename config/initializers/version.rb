# Đọc phiên bản ứng dụng từ version.txt (do release-please quản lý) một lần lúc khởi động.
# Thiếu file hoặc file rỗng → "unknown" để ứng dụng vẫn khởi động được.
module ElectricWaterManagement
  version_file = Rails.root.join("version.txt")
  VERSION = ((File.exist?(version_file) ? File.read(version_file).strip.presence : nil) || "unknown").freeze
end

# Ghi một dòng log khởi động kèm phiên bản + môi trường để truy vết bản phát hành.
# Dùng after_initialize để SystemInfo (lib/) đã sẵn sàng, tránh autoload lúc khởi tạo.
Rails.application.config.after_initialize do
  Rails.logger.info(
    "Booting ElectricWaterManagement version=#{ElectricWaterManagement::VERSION} " \
    "environment=#{SystemInfo.environment_label} rails_env=#{Rails.env}"
  )
end
