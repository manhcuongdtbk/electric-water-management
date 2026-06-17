import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { loadingText: String }

  connect() {
    this.originalText = this.element.textContent
    this.element.addEventListener("turbo:submit-start", this.start.bind(this))
    this.element.addEventListener("turbo:submit-end", this.stop.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.start.bind(this))
    this.element.removeEventListener("turbo:submit-end", this.stop.bind(this))
  }

  start() {
    const button = this.element.querySelector("button[type='submit'], input[type='submit']") || this.element
    this.originalText = button.textContent || button.value
    button.disabled = true
    if (button.tagName === "INPUT") {
      button.value = this.loadingTextValue
    } else {
      button.textContent = this.loadingTextValue
    }
    button.classList.add("opacity-75", "cursor-wait")
  }

  stop() {
    const button = this.element.querySelector("button[type='submit'], input[type='submit']") || this.element
    button.disabled = false
    if (button.tagName === "INPUT") {
      button.value = this.originalText
    } else {
      button.textContent = this.originalText
    }
    button.classList.remove("opacity-75", "cursor-wait")
  }
}
