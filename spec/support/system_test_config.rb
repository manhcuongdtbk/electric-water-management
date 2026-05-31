# Driver cho system test (type: :system).
#
# Trong image development (Docker): Chromium + chromedriver được cài sẵn bằng gói
# Debian (arm64). Trỏ thẳng tới hai binary theo đường dẫn cố định để KHÔNG phụ
# thuộc Selenium Manager tải chromedriver lúc chạy — vừa nhanh, vừa chạy được khi
# offline, và tránh việc Chrome for Testing không có bản chromedriver cho arm64.
#
# Trên máy host (bin/dev, không có hai binary này): để Selenium Manager tự tìm
# Chrome/chromedriver như mặc định, nên system test vẫn chạy được ngoài Docker.
#
# Container development chạy bằng root nên Chromium bắt buộc có --no-sandbox.
Capybara.register_driver :headless_chromium do |app|
  chromium_binary = "/usr/bin/chromium"
  chromedriver_binary = "/usr/bin/chromedriver"

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1280,900")
  options.binary = chromium_binary if File.exist?(chromium_binary)

  driver_arguments = { browser: :chrome, options: options }
  if File.exist?(chromedriver_binary)
    driver_arguments[:service] = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_binary)
  end

  Capybara::Selenium::Driver.new(app, **driver_arguments)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chromium
  end
end
