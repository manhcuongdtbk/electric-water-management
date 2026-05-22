RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900] do |driver_option|
      driver_option.add_argument("--disable-gpu")
      driver_option.add_argument("--no-sandbox")
    end
  end
end
