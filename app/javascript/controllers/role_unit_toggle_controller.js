import { Controller } from "@hotwired/stimulus"

const NON_UNIT_SCOPED_ROLES = ["system_admin", "technician", "division_commander"]

export default class extends Controller {
  static targets = ["role", "unitContainer", "unitSelect"]

  connect() {
    this.toggle()
  }

  toggle() {
    const role = this.roleTarget.value
    const disabled = NON_UNIT_SCOPED_ROLES.includes(role)

    this.unitContainerTarget.classList.toggle("hidden", disabled)

    if (disabled) {
      this.unitSelectTarget.value = ""
    }

    this.unitSelectTarget.disabled = disabled
  }
}
