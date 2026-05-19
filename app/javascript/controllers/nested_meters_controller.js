import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "entry", "template"]

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, Date.now())
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    const entry = event.target.closest("[data-nested-meters-target='entry']")
    const visibleCount = this.entryTargets.filter(e => !e.classList.contains("hidden")).length

    if (visibleCount <= 1) return

    const idField = entry.querySelector("input[name*='[id]']")
    if (idField) {
      const destroyField = entry.querySelector("input[name*='[_destroy]']")
      if (destroyField) destroyField.value = "1"
      entry.classList.add("hidden")
    } else {
      entry.remove()
    }
  }
}
