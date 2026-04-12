import { Controller } from "@hotwired/stimulus"

// Realtime calculation for F04 unit config — cột "Khác".
// Personnel counts per contact_point are passed via data-unit-config-personnel-value.
export default class extends Controller {
  static values = {
    personnel: Object  // { "cp_id_string": total_count }
  }

  connect() {
    this.#recalculateAll()
  }

  // Triggered by change on type select or input on value field.
  calculateRow(event) {
    const row = event.target.closest("tr[data-cp-id]")
    if (row) this.#recalculateRow(row)
  }

  #recalculateAll() {
    this.element.querySelectorAll("tr[data-cp-id]").forEach(row => {
      this.#recalculateRow(row)
    })
  }

  #recalculateRow(row) {
    const cpId = row.dataset.cpId
    const typeEl = row.querySelector("[data-role='other-type']")
    const valueEl = row.querySelector("[data-role='other-value']")
    const resultEl = row.querySelector("[data-role='other-result']")

    if (!typeEl || !valueEl || !resultEl) return

    const type = typeEl.value
    const value = parseFloat(valueEl.value) || 0
    const personnel = parseInt(this.personnelValue[String(cpId)] || 0, 10)

    const result = type === "factor_per_person" ? value * personnel : value

    resultEl.textContent = result.toLocaleString("vi-VN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
