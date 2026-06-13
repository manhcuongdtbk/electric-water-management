# Capybara driver for demo specs (spec/demo, type: :demo) ONLY. Uses Playwright
# to record a native WebM per example. The main suite keeps :headless_chromium
# (Selenium) — see spec/support/system_test_config.rb and ADR-036.
#
# Node.js is NOT required: a standalone Playwright driver bundle (node binary +
# cli.js) is downloaded from playwright.azureedge.net during env setup and a
# wrapper shell script is placed at /usr/local/bin/playwright-driver. CI will
# replicate this step. See ADR-036.
require "capybara-playwright-driver"

# Directory where recorded videos are collected (gitignored; CI uploads them).
DEMO_VIDEO_DIR = Rails.root.join("tmp", "demo_videos").freeze

Capybara.register_driver :playwright_demo do |app|
  Capybara::Playwright::Driver.new(
    app,
    playwright_cli_executable_path: ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "/usr/local/bin/playwright-driver"),
    browser_type: :chromium,
    headless: true,
    # Passing record_video_dir here ensures the Playwright browser context is
    # created with video recording enabled regardless of when on_save_screenrecord
    # is registered. The callback renames the raw temp file to a descriptive name.
    record_video_dir: DEMO_VIDEO_DIR.to_s
  )
end

RSpec.configure do |config|
  # Include Capybara DSL for :demo type (Capybara only auto-includes for :system
  # and :feature by default; :demo is a custom type).
  config.include Capybara::DSL, type: :demo
  config.include Capybara::RSpecMatchers, type: :demo

  config.before(:each, type: :demo) do
    FileUtils.mkdir_p(DEMO_VIDEO_DIR)
    # Switch to the Playwright driver for this example.
    Capybara.current_driver = :playwright_demo
    # Register the video rename callback BEFORE any page interaction so
    # Browser.new receives record_video: true and starts the recording context.
    # Capybara.reset_sessions! (fired in Capybara's own after hook, after user
    # after hooks) calls driver.reset! which invokes this callback with the path.
    page.driver.on_save_screenrecord do |video_path|
      safe = RSpec.current_example.full_description.parameterize(separator: "_")
      dest = DEMO_VIDEO_DIR.join("#{safe}.webm")
      FileUtils.mv(video_path, dest)
    end
  end

  config.after(:each, type: :demo) do
    # Restore the default driver after each demo spec so leaking driver does not
    # affect anything if specs are somehow run together.
    Capybara.use_default_driver
  end
end
