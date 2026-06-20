# Thin wrapper over Capybara for demo specs. Each step injects a Vietnamese
# caption banner (DOM, captured by the video) and paces the action so a viewer
# can follow. See docs/superpowers/specs/2026-06-13-tu-dong-hoa-demo-design.md.
class DemoRecorder
  INJECT_JS = File.read(Rails.root.join(".github", "demo-recorder", "inject.js")).freeze

  # Seconds to hold each caption so it is readable in the recording. Override
  # with DEMO_STEP_PAUSE for faster local iteration.
  STEP_PAUSE = Float(ENV.fetch("DEMO_STEP_PAUSE", "1.2"))

  def initialize(spec)
    @spec = spec # the RSpec example, for Capybara DSL (page, visit, ...)
  end

  def visit(path, caption:)
    page.visit(path)
    show_caption(caption)
  end

  # `confirm: true` accepts the Turbo confirmation dialog (data-turbo-confirm)
  # that the clicked control triggers. The Playwright driver's DEFAULT dialog
  # handler DISMISSES confirm dialogs, so without this the form is cancelled and
  # never submits (e.g. the billing "Tính toán lại" button). See #363.
  def click(locator, caption:, confirm: false)
    show_caption(caption)
    el = page.find(:link_or_button, locator)
    point_and_pause(el)
    page.execute_script("window.__demo.ripple();")
    if confirm
      page.accept_confirm { el.click }
    else
      el.click
    end
    unpoint
  end

  def fill(field, with:, caption:)
    show_caption(caption)
    el = page.find_field(field)
    point_and_pause(el)
    el.set(with)
    unpoint
  end

  # Select an option (by visible text) from a <select> located by `from` (id,
  # name, or label — anything Capybara find_field accepts).
  def select(option, from:, caption:)
    show_caption(caption)
    el = page.find_field(from)
    point_and_pause(el)
    el.find(:option, text: option).select_option
    unpoint
  end

  # Scroll an element (by CSS selector) into view and outline it, so a specific
  # result is visibly surfaced in the recording — e.g. one cell deep in the wide
  # billing table. No click; just draws attention. See #363.
  def highlight(selector, caption:)
    show_caption(caption)
    page.execute_script("window.__demo.point(arguments[0]);", selector)
    sleep STEP_PAUSE
    unpoint
  end

  # Show a caption with no action — for narrating context between steps.
  def narrate(caption)
    show_caption(caption)
  end

  # Authenticate as `user` (a User record) WITHOUT rendering /users/sign_in.
  # Replaces the 4-step visit→fill→fill→click login that every demo used to
  # repeat — showing the login form is slow and tells the customer nothing.
  #
  # Uses Devise's sign_in helper (Devise::Test::IntegrationHelpers, mixed into
  # the example for type: :demo in spec/support/auth_helpers.rb) — the SAME
  # mechanism system specs use (`sign_in system_admin`). It injects the user
  # through Warden's test middleware server-side, so the session is established
  # for the real-browser Playwright driver. We then open the app root already
  # authenticated and show a single caption naming the role.
  #
  # Use this for role switches too (e.g. admin → commander). Devise's sign_in
  # replaces the Warden user, so a second call switches the authenticated user
  # without a visible logout+login.
  def sign_in_as(user, role_label:, caption: nil)
    @spec.sign_in(user)
    page.visit("/")
    show_caption(caption || "Đăng nhập bằng tài khoản #{role_label}")
  end

  private

  def page
    @spec.page
  end

  def point_and_pause(element)
    selector = element[:id].present? ? "##{element[:id]}" : nil
    page.execute_script("window.__demo.point(arguments[0]);", selector) if selector
    sleep STEP_PAUSE
  end

  def show_caption(text)
    page.execute_script(INJECT_JS)
    page.execute_script("window.__demo.caption(arguments[0]);", text)
    sleep STEP_PAUSE
  end

  # Clear the highlight outline — best-effort. A click/fill may have navigated the
  # page, so the script can race the new (un-injected) document; the highlight is
  # gone with the old page either way, so a failure here must never fail the demo.
  def unpoint
    page.execute_script("window.__demo.unpoint();")
  rescue StandardError
    nil
  end
end
