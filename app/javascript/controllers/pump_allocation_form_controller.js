import { Controller } from "@hotwired/stimulus"

// Quản lý 2 cặp XOR field trên form Phân bổ bơm nước:
//   1. Đối tượng nhận: Đơn vị (unit_id) HOẶC Đầu mối (contact_point_id)
//   2. Chế độ phân bổ: % cố định (fixed_percentage) HOẶC Hệ số (coefficient)
//
// Khi user chọn mode → ẩn nhóm field còn lại + clear/reset value
// để server nhận đúng giá trị (null cho fixed_percentage, 0 cho coefficient).
export default class extends Controller {
  static targets = [
    "targetMode",      // radio inputs cho unit/contact_point
    "targetUnit",      // wrapper div + select unit_id
    "targetContact",   // wrapper div + select contact_point_id
    "allocMode",       // radio inputs cho fixed/coefficient
    "allocFixed",      // wrapper div + input fixed_percentage
    "allocCoefficient" // wrapper div + input coefficient
  ]

  connect() {
    this.refreshTarget()
    this.refreshAlloc()
  }

  refreshTarget() {
    const mode = this.selectedTargetMode()
    if (mode === "unit") {
      this.show(this.targetUnitTarget)
      this.hide(this.targetContactTarget)
      this.clearSelect(this.targetContactTarget)
    } else {
      this.hide(this.targetUnitTarget)
      this.show(this.targetContactTarget)
      this.clearSelect(this.targetUnitTarget)
    }
  }

  refreshAlloc() {
    const mode = this.selectedAllocMode()
    if (mode === "fixed") {
      this.show(this.allocFixedTarget)
      this.hide(this.allocCoefficientTarget)
      // coefficient phải có giá trị (validates presence). Set = 0 để engine ignore khi có fixed_percentage.
      this.setInput(this.allocCoefficientTarget, "0")
    } else {
      this.hide(this.allocFixedTarget)
      this.show(this.allocCoefficientTarget)
      this.clearInput(this.allocFixedTarget)
    }
  }

  selectedTargetMode() {
    const checked = this.targetModeTargets.find((r) => r.checked)
    return checked ? checked.value : "unit"
  }

  selectedAllocMode() {
    const checked = this.allocModeTargets.find((r) => r.checked)
    return checked ? checked.value : "coefficient"
  }

  show(el) {
    el.classList.remove("hidden")
  }

  hide(el) {
    el.classList.add("hidden")
  }

  clearSelect(wrapper) {
    const select = wrapper.querySelector("select")
    if (select) select.value = ""
  }

  clearInput(wrapper) {
    const input = wrapper.querySelector("input")
    if (input) input.value = ""
  }

  setInput(wrapper, value) {
    const input = wrapper.querySelector("input")
    if (input) input.value = value
  }
}
