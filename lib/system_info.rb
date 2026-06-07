# Nguồn sự thật duy nhất cho phiên bản + nhãn môi trường của ứng dụng đang chạy.
# Module (namespace không trạng thái, không khởi tạo) — view, endpoint, Excel và log đều gọi tới đây.
# Đặt ở lib/ (mối quan tâm hạ tầng) để app/services/ thuần class domain.
module SystemInfo
  # Đọc version.txt (do release-please quản lý) một lần khi nạp module.
  # Thiếu file hoặc file rỗng → "unknown" để ứng dụng vẫn khởi động được.
  version_file = Rails.root.join("version.txt")
  VERSION = ((File.exist?(version_file) ? File.read(version_file).strip.presence : nil) || "unknown").freeze

  def self.version
    VERSION
  end

  # Nhãn môi trường là tiếng Anh (định danh triển khai). Ops đặt APP_ENVIRONMENT_LABEL
  # cho từng nơi triển khai (ví dụ Acceptance / Mirror / Production); trống → Rails.env.
  def self.environment_label
    ENV["APP_ENVIRONMENT_LABEL"]&.strip.presence || Rails.env.to_s.capitalize
  end

  def self.to_h
    { version: version, environment: environment_label, rails_env: Rails.env.to_s }
  end

  # Một tag gộp cho log: "v1.0.1 Production".
  def self.log_tag
    "v#{version} #{environment_label}"
  end
end
