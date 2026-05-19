import { Controller } from "@hotwired/stimulus"

// Filter dropdown khối theo đơn vị đã chọn trên form Nhóm.
// Mỗi option khối có data-unit-id; chỉ hiển thị option có unit-id khớp.
export default class extends Controller {
  static targets = ["unitSelect", "blockSelect"]

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasUnitSelectTarget || !this.hasBlockSelectTarget) return
    const unitId = this.unitSelectTarget.value
    let currentSelectionStillValid = false
    Array.from(this.blockSelectTarget.options).forEach((option) => {
      if (option.value === "") {
        option.hidden = false
        return
      }
      if (unitId === "") {
        option.hidden = false
        return
      }
      const match = option.dataset.unitId === unitId
      option.hidden = !match
      if (option.selected && match) currentSelectionStillValid = true
    })
    if (!currentSelectionStillValid && unitId !== "") {
      this.blockSelectTarget.value = ""
    }
  }
}
