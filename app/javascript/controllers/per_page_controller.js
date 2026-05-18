import { Controller } from "@hotwired/stimulus"

// Submit form khi user đổi số dòng mỗi trang.
// Lưu lựa chọn vào localStorage để giữ giữa các phiên.
export default class extends Controller {
  static values = { storageKey: { type: String, default: "list_per_page" } }

  connect() {
    if (!this.hasStorageKeyValue) return
    const stored = window.localStorage.getItem(this.storageKeyValue)
    const url = new URL(window.location.href)
    if (stored && !url.searchParams.has("per_page") && this.element.value !== stored) {
      const valid = Array.from(this.element.options).some((o) => o.value === stored)
      if (valid) {
        this.element.value = stored
      }
    }
  }

  submit() {
    if (this.hasStorageKeyValue) {
      window.localStorage.setItem(this.storageKeyValue, this.element.value)
    }
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
