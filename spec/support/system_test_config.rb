# Cấu hình Capybara cho system test (các spec trong spec/system, type: :system).
#
# System test mở trình duyệt THẬT (Chromium) điều khiển qua Selenium + chromedriver
# để kiểm thử hành vi cần JavaScript / tương tác người dùng (auto-submit, cascade
# filter, modal xác nhận, ...). Request/model/service spec KHÔNG nạp file này.
#
# Hai bối cảnh chạy được hỗ trợ:
#   1. Trong Docker (chuẩn): image development đã cài sẵn Chromium + chromedriver
#      (gói Debian, kiến trúc arm64) ở /usr/bin — xem Dockerfile.dev. Ta trỏ THẲNG
#      tới hai binary này để Selenium KHÔNG phải nhờ Selenium Manager tải chromedriver
#      lúc chạy (Chrome for Testing không có bản arm64; trỏ tay vừa nhanh, vừa chạy
#      được offline, vừa luôn khớp phiên bản vì cùng do Debian phát hành).
#   2. Trên máy host (chạy bằng bin/dev, không có hai binary đó): bỏ qua phần trỏ
#      đường dẫn, để Selenium Manager tự tìm Chrome + chromedriver như mặc định, nên
#      system test vẫn chạy được ngoài Docker.

# Đăng ký một driver Capybara tên :headless_chromium dùng cho mọi system test.
# `app` là ứng dụng Rack mà Capybara dựng server test cho nó.
Capybara.register_driver :headless_chromium do |app|
  # Đường dẫn Chromium + chromedriver cài sẵn trong image development (Dockerfile.dev).
  # Trên host thường không tồn tại hai file này → các nhánh File.exist? bên dưới sẽ bỏ qua.
  chromium_binary = "/usr/bin/chromium"
  chromedriver_binary = "/usr/bin/chromedriver"

  # Đối tượng options gom mọi cờ dòng lệnh truyền cho Chromium khi khởi động.
  options = Selenium::WebDriver::Chrome::Options.new

  # Chạy headless (không cửa sổ) — mặc định, hợp cho CI/Docker và chạy nhanh.
  # Đặt HEADLESS=false để BẬT cửa sổ thật khi cần nhìn test chạy / debug. Chỉ có
  # tác dụng trên host (bin/dev) vì container không có màn hình; xem hướng dẫn
  # "chạy headful" trong docs/KIEN_THUC_DOCKER.md.
  options.add_argument("--headless=new") unless ENV["HEADLESS"] == "false"

  # Container development chạy bằng root; Chromium từ chối bật sandbox khi là root,
  # nên bắt buộc tắt sandbox (chấp nhận được vì đây là môi trường test cô lập).
  options.add_argument("--no-sandbox")

  # Container không có GPU → tắt tăng tốc GPU để tránh lỗi/cảnh báo vô nghĩa.
  options.add_argument("--disable-gpu")

  # /dev/shm trong container mặc định rất nhỏ (64MB) → Chromium dễ crash khi render
  # trang lớn. Cờ này cho Chromium dùng /tmp thay cho /dev/shm.
  options.add_argument("--disable-dev-shm-usage")

  # Kích thước cửa sổ ảo (thay cho screen_size cũ) — đủ rộng để hiện layout desktop.
  options.add_argument("--window-size=1280,900")

  # Trong Docker: trỏ Selenium tới đúng Chromium đã cài (mặc định nó tìm google-chrome,
  # không có trong image). Trên host: bỏ qua, để Selenium Manager tự tìm trình duyệt.
  options.binary = chromium_binary if File.exist?(chromium_binary)

  # Gom tham số tạo driver. Không có :service → Selenium Manager tự lo chromedriver (host).
  driver_arguments = { browser: :chrome, options: options }

  # Trong Docker: chỉ định thẳng chromedriver hệ thống → bỏ qua Selenium Manager
  # (không tải gì lúc chạy, chạy được cả khi offline, khớp đúng phiên bản Chromium).
  if File.exist?(chromedriver_binary)
    driver_arguments[:service] = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_binary)
  end

  # Tạo driver Capybara bọc Selenium với toàn bộ cấu hình trên.
  Capybara::Selenium::Driver.new(app, **driver_arguments)
end

# Trước mỗi system test, chọn driver :headless_chromium vừa đăng ký.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chromium
  end
end
