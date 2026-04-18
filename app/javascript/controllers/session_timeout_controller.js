import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { expiresAt: Number, timeoutIn: Number }
  static targets = ["modal", "countdown"]

  disconnect() {
    clearTimeout(this.warningTimeout)
    clearInterval(this.countdownInterval)
  }

  expiresAtValueChanged() {
    clearTimeout(this.warningTimeout)
    clearInterval(this.countdownInterval)
    this.modalTarget.hidden = true
    this.scheduleWarning()
  }

  scheduleWarning() {
    if (!this.expiresAtValue) return
    const warningAt = this.expiresAtValue - 600
    const delay = (warningAt - Math.floor(Date.now() / 1000)) * 1000
    if (delay <= 0) {
      this.showModal()
    } else {
      this.warningTimeout = setTimeout(() => this.showModal(), delay)
    }
  }

  showModal() {
    this.modalTarget.hidden = false
    this.startCountdown()
  }

  startCountdown() {
    this.updateCountdown()
    this.countdownInterval = setInterval(() => {
      const remaining = this.expiresAtValue - Math.floor(Date.now() / 1000)
      if (remaining <= 0) {
        clearInterval(this.countdownInterval)
        window.location.reload()
        return
      }
      this.updateCountdown()
    }, 1000)
  }

  updateCountdown() {
    const remaining = Math.max(0, this.expiresAtValue - Math.floor(Date.now() / 1000))
    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60
    this.countdownTarget.textContent =
      `${minutes} phút ${seconds.toString().padStart(2, "0")} giây`
  }

  async keepAlive() {
    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const headers = csrfMeta ? { "X-CSRF-Token": csrfMeta.content } : {}
    const response = await fetch("/sessions/extend", { method: "POST", headers })
    if (response.ok) {
      this.expiresAtValue = Math.floor(Date.now() / 1000) + this.timeoutInValue
    }
  }
}
