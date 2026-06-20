module AuthHelpers
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  # Demo specs drive a real browser (Playwright) like system specs, so they
  # authenticate the same way: Devise's sign_in helper (via Warden's test
  # middleware) establishes the session server-side. DemoRecorder#sign_in_as
  # calls @spec.sign_in(user) — see spec/support/demo_recorder.rb.
  config.include Devise::Test::IntegrationHelpers, type: :demo
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include AuthHelpers, type: :request
end
