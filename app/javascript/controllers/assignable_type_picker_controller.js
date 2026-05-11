import { Controller } from "@hotwired/stimulus"

// Toggles which assignable select is visible based on the chosen
// "Loại nhóm đối tượng" radio. Disables the inactive selects so their
// blank values are not posted alongside the active one.
export default class extends Controller {
  static targets = [ "radio", "field" ]

  connect() {
    this.updateVisibility()
  }

  typeChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
    const selectedType = this.selectedType()

    this.fieldTargets.forEach((field) => {
      const fieldType = field.dataset.assignableType
      const isActive = fieldType === selectedType
      field.classList.toggle("hidden", !isActive)

      const select = field.querySelector("select")
      if (select) {
        select.disabled = !isActive
        select.required = isActive
        if (!isActive) select.value = ""
      }
    })
  }

  selectedType() {
    const checked = this.radioTargets.find((r) => r.checked)
    return checked ? checked.value : null
  }
}
