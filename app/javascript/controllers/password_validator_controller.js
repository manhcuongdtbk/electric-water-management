import { Controller } from "@hotwired/stimulus"

// Stimulus controller: validate độ phức tạp mật khẩu realtime.
// Hiển thị checklist tiếng Việt (✓/✗) cho 6 điều kiện và toggle nút submit.
// Server-side validation (User#password_complexity) vẫn là lớp cuối.
export default class extends Controller {
  static targets = ["password", "confirmation", "submit", "rule"]
  static values = { optional: Boolean }

  RULES = [
    { key: "length",  test: (v) => v.length >= 8 },
    { key: "upper",   test: (v) => /[A-Z]/.test(v) },
    { key: "lower",   test: (v) => /[a-z]/.test(v) },
    { key: "digit",   test: (v) => /\d/.test(v) },
    { key: "special", test: (v) => /[^A-Za-z0-9]/.test(v) }
  ]

  connect() {
    this.validate()
  }

  validate() {
    const password = this.hasPasswordTarget ? this.passwordTarget.value : ""
    const confirmation = this.hasConfirmationTarget ? this.confirmationTarget.value : null

    if (this.optionalValue && password.length === 0 && (confirmation === null || confirmation.length === 0)) {
      this.markAllNeutral()
      this.enableSubmit(true)
      return
    }

    let allPass = true
    this.RULES.forEach((rule) => {
      const passed = rule.test(password)
      const el = this.ruleTargets.find((e) => e.dataset.ruleKey === rule.key)
      if (el) this.applyRuleClass(el, passed)
      if (!passed) allPass = false
    })

    const matchEl = this.ruleTargets.find((e) => e.dataset.ruleKey === "match")
    if (matchEl) {
      const matches = confirmation !== null && password.length > 0 && password === confirmation
      this.applyRuleClass(matchEl, matches)
      if (!matches) allPass = false
    }

    this.enableSubmit(allPass)
  }

  enableSubmit(enable) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !enable
    this.submitTarget.classList.toggle("opacity-50", !enable)
    this.submitTarget.classList.toggle("cursor-not-allowed", !enable)
  }

  markAllNeutral() {
    this.ruleTargets.forEach((el) => {
      el.dataset.passed = "neutral"
      el.classList.remove("text-green-700", "text-red-600")
      el.classList.add("text-gray-500")
      const icon = el.querySelector("[data-rule-icon]")
      if (icon) icon.textContent = "○"
    })
  }

  applyRuleClass(el, passed) {
    el.dataset.passed = passed ? "true" : "false"
    el.classList.remove("text-gray-500")
    el.classList.toggle("text-green-700", passed)
    el.classList.toggle("text-red-600", !passed)
    const icon = el.querySelector("[data-rule-icon]")
    if (icon) icon.textContent = passed ? "✓" : "✗"
  }
}
