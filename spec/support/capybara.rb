require "capybara/rspec"

Capybara.register_driver :headless_chrome do |app|
  # Ask Selenium Manager to resolve ChromeDriver while skipping any older copy
  # sitting in PATH (e.g. homebrew chromedriver that lags behind Google Chrome).
  # Done inside the driver block so non-system specs pay zero overhead.
  chromedriver_path = Selenium::WebDriver::SeleniumManager
    .binary_paths("--browser", "chrome", "--skip-driver-in-path")
    .fetch("driver_path")
  Selenium::WebDriver::Chrome::Service.driver_path = chromedriver_path

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-software-rasterizer")
  options.add_argument("--window-size=1400,900")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :headless_chrome
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.include Warden::Test::Helpers, type: :system

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :headless_chrome
  end

  config.after(:each, type: :system) do
    Warden.test_reset!
  end
end
