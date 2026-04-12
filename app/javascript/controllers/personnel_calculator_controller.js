import { Controller } from "@hotwired/stimulus"

// Realtime calculation for F03 personnel declaration.
// Quotas are passed from the view via data attributes (loaded from DB).
export default class extends Controller {
  static values = {
    quotas: Object,   // { "1": 570, "2": 440, ..., "7": 24 }
    waterRate: Number // Personnel::WATER_PUMP_RATE = 9.45
  }

  static targets = [
    "rank1", "rank2", "rank3", "rank4", "rank5", "rank6", "rank7",
    "totalCount", "livingStandard", "waterStandard", "totalStandard"
  ]

  connect() {
    this.calculate()
  }

  calculate() {
    const quotas = this.quotasValue
    const waterRate = this.waterRateValue

    let totalCount = 0
    let livingStandard = 0

    for (let i = 1; i <= 7; i++) {
      const target = this[`rank${i}Target`]
      const count = Math.max(0, parseInt(target.value, 10) || 0)
      const quota = parseFloat(quotas[String(i)]) || 0
      totalCount += count
      livingStandard += count * quota
    }

    const waterStandard = totalCount * waterRate
    const totalStandard = livingStandard + waterStandard

    this.totalCountTarget.textContent = totalCount.toLocaleString("vi-VN")
    this.livingStandardTarget.textContent = this.#formatKw(livingStandard)
    this.waterStandardTarget.textContent = this.#formatKw(waterStandard)
    this.totalStandardTarget.textContent = this.#formatKw(totalStandard)
  }

  #formatKw(value) {
    return value.toLocaleString("vi-VN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
