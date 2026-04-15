require "capybara/rspec"

# Ask Selenium Manager to resolve ChromeDriver while skipping any older copy
# sitting in PATH (e.g. homebrew chromedriver that lags behind Google Chrome).
# We only call this once per test run and cache the result — Selenium's DriverFinder
# then bypasses its own resolution because Service.driver_path is already set.
chromedriver_path = Selenium::WebDriver::SeleniumManager
  .binary_paths("--browser", "chrome", "--skip-driver-in-path")
  .fetch("driver_path")
Selenium::WebDriver::Chrome::Service.driver_path = chromedriver_path

Capybara.register_driver :headless_chrome do |app|
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

# Rails 8 + allow_browser versions: :modern requires Chrome 99+ user agent.
# Silence Capybara server exceptions so we get nicer errors.
Capybara.raise_server_errors = true

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
