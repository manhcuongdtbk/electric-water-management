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
    "allocCoefficient",// wrapper div + input coefficient
    "zoneSelect",      // select zone_id
    "unitSelect",      // select unit_id (cần filter theo zone)
    "contactSelect"    // select contact_point_id (cần filter theo zone)
  ]

  connect() {
    this.refreshTarget()
    this.refreshAlloc()
    this.refreshZoneScope()
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

  // Filter unit/contact_point dropdown theo zone đang chọn.
  // Mỗi option có data-zone-id; option có zone-id khớp (hoặc rỗng = include_blank) thì hiển thị.
  refreshZoneScope() {
    if (!this.hasZoneSelectTarget) return
    const zoneId = this.zoneSelectTarget.value
    if (this.hasUnitSelectTarget) this.filterOptionsByZone(this.unitSelectTarget, zoneId)
    if (this.hasContactSelectTarget) this.filterOptionsByZone(this.contactSelectTarget, zoneId)
  }

  filterOptionsByZone(select, zoneId) {
    let currentSelectionStillValid = false
    Array.from(select.options).forEach((option) => {
      const optionZone = option.dataset.zoneId
      // Blank option (include_blank) luôn hiển thị
      if (option.value === "") {
        option.hidden = false
        return
      }
      // Không có zone đang chọn → hiển thị tất cả (chưa filter)
      if (zoneId === "") {
        option.hidden = false
        return
      }
      const match = optionZone === zoneId
      option.hidden = !match
      if (option.selected && match) currentSelectionStillValid = true
    })
    if (!currentSelectionStillValid && zoneId !== "") {
      select.value = ""
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
