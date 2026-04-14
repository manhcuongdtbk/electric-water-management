import { Controller } from "@hotwired/stimulus"

// Realtime consumption calculation for F06 meter readings.
// consumption = reading_end - reading_start
// Shows "—" when reading_end is blank. Turns red when end < start.
export default class extends Controller {
  static targets = ["start", "end", "consumption"]

  connect() {
    this.calculate()
  }

  calculate() {
    if (!this.hasStartTarget || !this.hasEndTarget || !this.hasConsumptionTarget) return

    const endVal = this.endTarget.value.trim()

    if (!endVal) {
      this.consumptionTarget.textContent = "—"
      this.#setInvalid(false)
      return
    }

    const start = parseFloat(this.startTarget.value) || 0
    const end = parseFloat(endVal) || 0
    const diff = end - start

    this.consumptionTarget.textContent = diff.toLocaleString("vi-VN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })

    this.#setInvalid(diff < 0)
  }

  #setInvalid(invalid) {
    this.consumptionTarget.classList.toggle("text-red-600", invalid)
    this.consumptionTarget.classList.toggle("font-semibold", invalid)
    this.consumptionTarget.classList.toggle("text-gray-900", !invalid)
  }
}
