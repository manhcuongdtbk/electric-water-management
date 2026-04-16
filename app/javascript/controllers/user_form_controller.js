import { Controller } from "@hotwired/stimulus"

// Toggles org dropdown visibility based on selected role.
// Org is required only for admin_unit and commander roles.
export default class extends Controller {
  static targets = [ "roleSelect", "orgField" ]

  connect() {
    this.toggleOrgField()
  }

  roleChanged() {
    this.toggleOrgField()
  }

  toggleOrgField() {
    const role = this.roleSelectTarget.value
    const needsOrg = role === "admin_unit" || role === "commander"
    this.orgFieldTarget.style.display = needsOrg ? "" : "none"

    const select = this.orgFieldTarget.querySelector("select")
    if (select) {
      select.required = needsOrg
      if (!needsOrg) select.value = ""
    }
  }
}
