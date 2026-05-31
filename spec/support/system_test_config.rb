# Cấu hình Capybara cho system test (các spec trong spec/system, type: :system).
#
# System test mở trình duyệt THẬT (Chromium) điều khiển qua Selenium + chromedriver
# để kiểm thử hành vi cần JavaScript / tương tác người dùng (auto-submit, cascade
# filter, modal xác nhận, ...). Request/model/service spec KHÔNG nạp file này.
#
# Hai bối cảnh chạy được hỗ trợ:
#   1. Trong Docker (chuẩn): image development đã cài sẵn Chromium + chromedriver
#      (gói Debian) ở /usr/bin — xem Dockerfile.dev. Ta trỏ THẲNG tới hai binary này
#      để Selenium KHÔNG phải nhờ Selenium Manager tải chromedriver lúc chạy: vừa
#      nhanh, vừa chạy được offline, vừa luôn khớp phiên bản (cùng do Debian phát
#      hành), và không phụ thuộc việc Chrome for Testing có sẵn driver cho kiến trúc
#      CPU đang dùng hay không.
#   2. Ngoài Docker — chạy rspec trực tiếp trên máy host (nơi có Ruby + trình duyệt):
#      hai binary trên thường không tồn tại → bỏ qua phần trỏ đường dẫn, để Selenium
#      Manager tự tìm Chrome + tải chromedriver khớp. Nhờ vậy system test chạy được
#      cả ngoài Docker.
#
# Các tham số chỉnh qua biến môi trường (không cần sửa file):
#   HEADLESS=false          Hiện cửa sổ trình duyệt thật thay vì chạy ẩn — dùng khi
#                           cần quan sát trực tiếp những gì trình duyệt làm. Chỉ có
#                           tác dụng khi máy có màn hình (tức chạy ngoài Docker).
#   WINDOW_SIZE=1440,900    Kích thước cửa sổ (mặc định 1280,900).
#   CHROMIUM_BINARY=...      Đường dẫn trình duyệt (mặc định /usr/bin/chromium).
#   CHROMEDRIVER_BINARY=...  Đường dẫn chromedriver (mặc định /usr/bin/chromedriver).

# Đăng ký một driver Capybara tên :headless_chromium dùng cho mọi system test.
# `app` là ứng dụng Rack mà Capybara dựng server test cho nó.
Capybara.register_driver :headless_chromium do |app|
  # Đường dẫn binary — mặc định trỏ tới Chromium/chromedriver cài trong image
  # development. Override bằng ENV khi binary nằm chỗ khác (vd cài tay trên host).
  chromium_binary = ENV.fetch("CHROMIUM_BINARY", "/usr/bin/chromium")
  chromedriver_binary = ENV.fetch("CHROMEDRIVER_BINARY", "/usr/bin/chromedriver")

  # Đối tượng options gom mọi cờ dòng lệnh truyền cho Chromium khi khởi động.
  options = Selenium::WebDriver::Chrome::Options.new

  # Mặc định chạy headless (không cửa sổ) — hợp cho CI/Docker và chạy nhanh. Đặt
  # HEADLESS=false để hiện cửa sổ trình duyệt thật khi cần quan sát trực tiếp những
  # gì trình duyệt làm (vd: debug, xem từng bước, dựng lại flow lỗi, ...). Chỉ có tác
  # dụng khi máy có màn hình — tức chạy ngoài Docker; xem docs/KIEN_THUC_DOCKER.md.
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
  options.add_argument("--window-size=#{ENV.fetch('WINDOW_SIZE', '1280,900')}")

  # Trỏ Selenium tới đúng Chromium đã chỉ định (mặc định nó tìm google-chrome, không
  # có trong image). Nếu binary không tồn tại (vd trên host) → bỏ qua, để Selenium
  # Manager tự tìm trình duyệt.
  options.binary = chromium_binary if File.exist?(chromium_binary)

  # Gom tham số tạo driver. Không có :service → Selenium Manager tự lo chromedriver.
  driver_arguments = { browser: :chrome, options: options }

  # Có chromedriver tại đường dẫn chỉ định (vd trong Docker) → dùng thẳng, bỏ qua
  # Selenium Manager (không tải gì lúc chạy, chạy được cả khi offline, khớp Chromium).
  # Không có (vd trên host) → để Selenium Manager tải bản chromedriver khớp Chrome.
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
