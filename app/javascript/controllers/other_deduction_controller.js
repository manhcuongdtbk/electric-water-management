import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "valueInput", "preview", "estimateLabel"]
  static values = {
    contactPointPersonnel: Number,
    unitTotalPersonnel: Number
  }

  connect() {
    this.updatePlaceholder()
    this.updatePreview()
  }

  typeChanged() {
    this.updatePlaceholder()
    this.updatePreview()
  }

  valueChanged() {
    this.updatePreview()
  }

  updatePlaceholder() {
    const type = this.typeSelectTarget.value
    if (type === "fixed") {
      this.valueInputTarget.placeholder = "kWh"
    } else {
      this.valueInputTarget.placeholder = "hệ số"
    }
  }

  updatePreview() {
    const type = this.typeSelectTarget.value
    const value = parseFloat(this.valueInputTarget.value)

    if ((type === "coefficient" || type === "unit_coefficient") && !isNaN(value)) {
      let personnel, formula
      if (type === "coefficient") {
        personnel = this.contactPointPersonnelValue
        const result = (value * personnel).toFixed(2)
        formula = `${value} × ${personnel} = ${this.formatNumber(result)} kWh`
      } else {
        const unitTotal = this.unitTotalPersonnelValue
        const cpPersonnel = this.contactPointPersonnelValue
        const diff = unitTotal - cpPersonnel
        const result = (value * diff).toFixed(2)
        formula = `${value} × (${unitTotal} − ${cpPersonnel}) = ${this.formatNumber(result)} kWh`
      }
      this.previewTarget.textContent = `≈ ${formula}`
      this.previewTarget.classList.remove("hidden")
    } else {
      this.previewTarget.classList.add("hidden")
      this.previewTarget.textContent = ""
    }

    if (this.hasEstimateLabelTarget) {
      if (type === "coefficient" || type === "unit_coefficient") {
        this.estimateLabelTarget.classList.remove("hidden")
      } else {
        this.estimateLabelTarget.classList.add("hidden")
      }
    }
  }

  formatNumber(numStr) {
    const parts = numStr.split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    return parts.join(",")
  }
}
