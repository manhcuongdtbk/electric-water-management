# Nguồn sự thật duy nhất cho phiên bản + môi trường ứng dụng (app environment) đang chạy.
# Module (namespace không trạng thái, không khởi tạo) — view, endpoint, Excel và log đều gọi tới đây.
# Đặt ở lib/ (mối quan tâm hạ tầng) để app/services/ thuần class domain.
#
# Phân biệt (xem glossary trong AGENTS.md):
#   - app_environment: nhãn NƠI triển khai (Acceptance / Mirror / Production…), do ops đặt.
#   - Rails.env (rails_env): chế độ runtime của Rails (development / test / production).
# Hai cái có thể khác nhau (vd Nghiệm thu và Mốc đều rails_env=production, app_environment khác nhau).
module SystemInfo
  # Đọc version.txt (do release-please quản lý) một lần khi nạp module.
  # Thiếu file hoặc file rỗng → "unknown" để ứng dụng vẫn khởi động được.
  version_file = Rails.root.join("version.txt")
  VERSION = ((File.exist?(version_file) ? File.read(version_file).strip.presence : nil) || "unknown").freeze

  def self.version
    VERSION
  end

  # Môi trường ứng dụng (app environment) — nhãn tiếng Anh cho nơi triển khai.
  # Ops đặt APP_ENVIRONMENT_LABEL cho từng nơi; trống → Rails.env.capitalize.
  def self.app_environment
    ENV["APP_ENVIRONMENT_LABEL"]&.strip.presence || Rails.env.to_s.capitalize
  end

  def self.to_h
    { version: version, app_environment: app_environment, rails_env: Rails.env.to_s }
  end

  # Một tag gộp cho log: "v1.0.1 Production".
  def self.log_tag
    "v#{version} #{app_environment}"
  end
end
