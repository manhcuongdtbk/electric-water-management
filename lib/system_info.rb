# Nguồn sự thật duy nhất cho phiên bản + nhãn môi trường của ứng dụng đang chạy.
# Module không trạng thái: view, endpoint, Excel và log đều gọi tới đây.
# Đặt ở lib/ (mối quan tâm hạ tầng) để app/services/ thuần class domain.
module SystemInfo
  module_function

  def version
    ElectricWaterManagement::VERSION
  end

  # Nhãn môi trường là tiếng Anh (định danh triển khai). Ops đặt APP_ENVIRONMENT_LABEL
  # cho từng nơi triển khai (ví dụ Acceptance / Mirror / Production); trống → Rails.env.
  def environment_label
    ENV["APP_ENVIRONMENT_LABEL"]&.strip.presence || Rails.env.to_s.capitalize
  end

  def to_h
    { version: version, environment: environment_label, rails_env: Rails.env.to_s }
  end

  # Một tag gộp cho log: "v1.0.1 Production".
  def log_tag
    "v#{version} #{environment_label}"
  end
end
