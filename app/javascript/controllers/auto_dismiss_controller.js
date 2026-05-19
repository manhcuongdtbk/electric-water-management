import { Controller } from "@hotwired/stimulus"

// Auto dismiss flash notice sau N ms (mặc định 5000).
// KHÔNG bind vào alert (lỗi cần user đọc).
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeoutId = window.setTimeout(() => this.dismiss(), this.delayValue)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500")
    window.setTimeout(() => this.element.remove(), 500)
  }

  disconnect() {
    if (this.timeoutId) window.clearTimeout(this.timeoutId)
  }
}
