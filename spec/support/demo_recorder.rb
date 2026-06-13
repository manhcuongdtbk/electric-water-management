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

  def click(locator, caption:)
    show_caption(caption)
    el = page.find(:link_or_button, locator)
    point_and_pause(el)
    page.execute_script("window.__demo.ripple();")
    el.click
    page.execute_script("window.__demo.unpoint();")
  end

  def fill(field, with:, caption:)
    show_caption(caption)
    el = page.find_field(field)
    point_and_pause(el)
    el.set(with)
    page.execute_script("window.__demo.unpoint();")
  end

  # Select an option (by visible text) from a <select> located by `from` (id,
  # name, or label — anything Capybara find_field accepts).
  def select(option, from:, caption:)
    show_caption(caption)
    el = page.find_field(from)
    point_and_pause(el)
    el.find(:option, text: option).select_option
    page.execute_script("window.__demo.unpoint();")
  end

  # Show a caption with no action — for narrating context between steps.
  def narrate(caption)
    show_caption(caption)
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
end
