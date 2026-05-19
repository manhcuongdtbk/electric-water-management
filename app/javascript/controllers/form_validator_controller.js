import { Controller } from "@hotwired/stimulus"

// Validator chung thay thế HTML5 validation (vốn hiển thị tooltip tiếng Anh
// của browser và không kiểm soát được style).
//
// Sử dụng:
//   <form data-controller="form-validator">
//     <input data-form-validator-target="input" data-validate="presence,numericality,min:0">
//   </form>
//
// Server-side validation (model) vẫn là lớp cuối — JS chỉ improve UX.
export default class extends Controller {
  static targets = ["input"]

  MESSAGES = {
    presence: "Trường này là bắt buộc",
    numericality: "Phải là số",
    min: "Giá trị tối thiểu là %{min}",
    max: "Giá trị tối đa là %{max}",
    length_min: "Tối thiểu %{n} ký tự"
  }

  ERROR_CLASS = "border-red-500"
  MESSAGE_CLASS = "text-red-600 text-xs mt-1"

  connect() {
    this.inputTargets.forEach((input) => {
      input.addEventListener("blur", () => this.validateInput(input))
      input.addEventListener("input", () => this.clearError(input))
    })
    this.element.addEventListener("submit", (event) => this.validateAll(event))
  }

  validateAll(event) {
    let hasError = false
    this.inputTargets.forEach((input) => {
      if (!this.validateInput(input)) hasError = true
    })
    if (hasError) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }

  validateInput(input) {
    const rules = this.parseRules(input.dataset.validate)
    if (rules.length === 0) return true

    const value = input.value
    for (const { name, arg } of rules) {
      const error = this.checkRule(name, value, arg, input)
      if (error) {
        this.showError(input, error)
        return false
      }
    }
    this.clearError(input)
    return true
  }

  parseRules(spec) {
    if (!spec) return []
    return spec.split(",").map((s) => s.trim()).filter(Boolean).map((token) => {
      const [name, arg] = token.split(":")
      return { name: name, arg: arg }
    })
  }

  checkRule(name, value, arg, input) {
    switch (name) {
      case "presence":
        if (value.toString().trim().length === 0) return this.message(input, "presence")
        return null
      case "numericality":
        if (value === "") return null
        if (Number.isNaN(Number(value))) return this.message(input, "numericality")
        return null
      case "min":
        if (value === "") return null
        if (Number(value) < Number(arg)) return this.message(input, "min", { min: arg })
        return null
      case "max":
        if (value === "") return null
        if (Number(value) > Number(arg)) return this.message(input, "max", { max: arg })
        return null
      case "length_min":
        if (value.length < Number(arg)) return this.message(input, "length_min", { n: arg })
        return null
      default:
        return null
    }
  }

  message(input, key, vars = {}) {
    const custom = input.dataset[`validateMessage${this.camelize(key)}`]
    const template = custom || this.MESSAGES[key] || ""
    return template.replace(/%\{(\w+)\}/g, (_, name) => vars[name] ?? "")
  }

  camelize(s) {
    return s.split("_").map((p, i) => i === 0 ? p[0].toUpperCase() + p.slice(1) : p[0].toUpperCase() + p.slice(1)).join("")
  }

  showError(input, message) {
    input.classList.add(this.ERROR_CLASS)
    let el = this.errorElement(input)
    if (!el) {
      el = document.createElement("p")
      el.className = this.MESSAGE_CLASS
      el.dataset.formValidatorErrorFor = input.id || input.name
      input.insertAdjacentElement("afterend", el)
    }
    el.textContent = message
  }

  clearError(input) {
    input.classList.remove(this.ERROR_CLASS)
    const el = this.errorElement(input)
    if (el) el.remove()
  }

  errorElement(input) {
    const id = input.id || input.name
    return this.element.querySelector(`[data-form-validator-error-for="${id}"]`)
  }
}
