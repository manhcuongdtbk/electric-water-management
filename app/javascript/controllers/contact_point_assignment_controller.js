import { Controller } from "@hotwired/stimulus"

// Toggle giữa "thuộc đơn vị" và "thuộc khu vực" trên form đầu mối
// residential/public. Đầu mối sinh hoạt thuộc khu vực (vd "Chỉ huy khu vực")
// không thuộc đơn vị nào, không có khối/nhóm.
//
// Khi đổi mode → clear values của fields nhóm bị ẩn (để server nhận đúng null).
// Khi đổi đơn vị → filter khối/nhóm chỉ hiển thị thuộc đơn vị đó.
export default class extends Controller {
  static targets = [
    "mode",
    "unitGroup",
    "zoneGroup",
    "unitSelect",
    "blockSelect",
    "groupSelect"
  ]

  connect() {
    this.refresh()
    this.refreshUnitScope()
  }

  refresh() {
    const mode = this.selectedMode()
    if (mode === "unit") {
      this.show(this.unitGroupTarget)
      this.hide(this.zoneGroupTarget)
      this.clearSelects(this.zoneGroupTarget)
    } else {
      this.hide(this.unitGroupTarget)
      this.show(this.zoneGroupTarget)
      this.clearSelects(this.unitGroupTarget)
    }
  }

  refreshUnitScope() {
    if (!this.hasUnitSelectTarget) return
    const unitId = this.unitSelectTarget.value
    if (this.hasBlockSelectTarget) this.filterOptionsByUnit(this.blockSelectTarget, unitId)
    this.refreshBlockScope()
  }

  refreshBlockScope() {
    if (!this.hasGroupSelectTarget) return
    const unitId = this.hasUnitSelectTarget ? this.unitSelectTarget.value : ""
    const blockId = this.hasBlockSelectTarget ? this.blockSelectTarget.value : ""

    let currentSelectionStillValid = false
    Array.from(this.groupSelectTarget.options).forEach((option) => {
      if (option.value === "") { option.hidden = false; return }
      if (unitId !== "" && option.dataset.unitId !== unitId) {
        option.hidden = true
        return
      }
      if (blockId === "") {
        option.hidden = false
        if (option.selected) currentSelectionStillValid = true
        return
      }
      const match = option.dataset.blockId === blockId
      option.hidden = !match
      if (option.selected && match) currentSelectionStillValid = true
    })
    if (!currentSelectionStillValid && (unitId !== "" || blockId !== "")) {
      this.groupSelectTarget.value = ""
    }
  }

  filterOptionsByUnit(select, unitId) {
    let currentSelectionStillValid = false
    Array.from(select.options).forEach((option) => {
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
      select.value = ""
    }
  }

  selectedMode() {
    const checked = this.modeTargets.find((r) => r.checked)
    return checked ? checked.value : "unit"
  }

  show(el) { el.classList.remove("hidden") }
  hide(el) { el.classList.add("hidden") }

  clearSelects(wrapper) {
    wrapper.querySelectorAll("select").forEach((s) => { s.value = "" })
    wrapper.querySelectorAll("input[type=hidden]").forEach((h) => { h.value = "" })
  }
}
