# Capybara driver for demo specs (spec/demo, type: :demo) ONLY. Uses Playwright
# to record a native WebM per example. The main suite keeps :headless_chromium
# (Selenium) — see spec/support/system_test_config.rb and ADR-038.
#
# Node.js + Playwright are provisioned in the dev Docker image (Dockerfile.dev)
# via NodeSource + npm install + npx playwright install. The driver auto-detects
# node_modules/.bin/playwright. Set PLAYWRIGHT_CLI_EXECUTABLE_PATH to override.
require "capybara-playwright-driver"

# Directory where recorded videos are collected (gitignored; CI uploads them).
DEMO_VIDEO_DIR = Rails.root.join("tmp", "demo_videos").freeze

Capybara.register_driver :playwright_demo do |app|
  driver_args = {
    browser_type: :chromium,
    headless: true,
    # Record at a fixed 720p so clips are crisp and consistent rather than the
    # small/letterboxed Playwright default. viewport sets the rendered page size;
    # record_video_size matches it (equal sizes avoid scaling blur).
    viewport: { width: 1280, height: 720 },
    record_video_size: { width: 1280, height: 720 },
    # Passing record_video_dir here ensures the Playwright browser context is
    # created with video recording enabled regardless of when on_save_screenrecord
    # is registered. The callback renames the raw temp file to a descriptive name.
    record_video_dir: DEMO_VIDEO_DIR.to_s
  }
  # Allow an explicit override (e.g. CI with a custom Playwright binary path).
  # When unset, capybara-playwright-driver auto-detects node_modules/.bin/playwright.
  cli = ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"]
  driver_args[:playwright_cli_executable_path] = cli if cli.present?
  Capybara::Playwright::Driver.new(app, **driver_args)
end

RSpec.configure do |config|
  # Include Capybara DSL for :demo type (Capybara only auto-includes for :system
  # and :feature by default; :demo is a custom type).
  config.include Capybara::DSL, type: :demo
  config.include Capybara::RSpecMatchers, type: :demo

  # Programmatic login for demos (DemoRecorder#sign_in_as) uses Devise's sign_in
  # helper, which injects the user through Warden's test middleware server-side —
  # so it works with the real-browser Playwright driver and skips rendering
  # /users/sign_in. Devise::Test::IntegrationHelpers (included for type: :demo in
  # spec/support/auth_helpers.rb) manages Warden's test mode and reset itself, so
  # no manual Warden.test_mode!/test_reset! is needed here.

  config.before(:each, type: :demo) do
    FileUtils.mkdir_p(DEMO_VIDEO_DIR)
    # Switch to the Playwright driver for this example.
    Capybara.current_driver = :playwright_demo
    # Register the video rename callback BEFORE any page interaction so
    # Browser.new receives record_video: true and starts the recording context.
    # Capybara.reset_sessions! (fired in Capybara's own after hook, after user
    # after hooks) calls driver.reset! which invokes this callback with the path.
    page.driver.on_save_screenrecord do |video_path|
      example = RSpec.current_example
      safe = (example.metadata[:demo_id] || example.full_description).parameterize(separator: "_")
      dest = DEMO_VIDEO_DIR.join("#{safe}.webm")
      FileUtils.mv(video_path, dest)

      # Append an authoritative clip→spec→NV mapping line for the release
      # bundler (rake demo:bundle, ADR-048). The transcode step turns the .webm
      # into "<safe>.mp4", so record the .mp4 name here. The demo job's artifact
      # upload globs *.mp4, so this sidecar file is harmless to it.
      # The NV anchor(s) come from the `demo_nv:` example metadata — the array
      # convention the `rails g demo:spec` scaffold writes (ADR-051, #352).
      File.open(DEMO_VIDEO_DIR.join("manifest.jsonl"), "a") do |io|
        io.puts(JSON.generate(
          video: "#{safe}.mp4",
          description: example.full_description,
          file: example.metadata[:file_path],
          nv: example.metadata[:demo_nv]
        ))
      end
    end
  end

  config.after(:each, type: :demo) do
    # Restore the default driver after each demo spec so leaking driver does not
    # affect anything if specs are somehow run together.
    Capybara.use_default_driver
  end
end
