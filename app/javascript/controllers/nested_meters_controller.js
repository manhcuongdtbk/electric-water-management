import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "entry", "template"]

  entryTargetConnected() { this.toggleRemoveButtons() }
  entryTargetDisconnected() { this.toggleRemoveButtons() }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, Date.now())
    this.containerTarget.insertAdjacentHTML("beforeend", html)
    this.toggleRemoveButtons()
  }

  remove(event) {
    const entry = event.target.closest("[data-nested-meters-target='entry']")
    if (!confirm("Bạn có chắc chắn muốn xóa công tơ này?")) return

    const idField = entry.querySelector("input[name*='[id]']")
    if (idField) {
      const destroyField = entry.querySelector("input[name*='[_destroy]']")
      if (destroyField) destroyField.value = "1"
      entry.classList.add("hidden")
    } else {
      entry.remove()
    }
    this.toggleRemoveButtons()
  }

  toggleRemoveButtons() {
    const visible = this.entryTargets.filter(e => !e.classList.contains("hidden"))
    const only = visible.length <= 1
    visible.forEach(entry => {
      const btn = entry.querySelector("[data-action='nested-meters#remove']")
      if (!btn) return
      btn.disabled = only
      btn.classList.toggle("opacity-50", only)
      btn.classList.toggle("cursor-not-allowed", only)
    })
  }
}
