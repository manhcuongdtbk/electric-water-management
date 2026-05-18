import { Controller } from "@hotwired/stimulus"

// Toggle giữa "thuộc đơn vị" và "thuộc khu vực" trên form đầu mối
// residential/public. Đầu mối sinh hoạt thuộc khu vực (vd "Chỉ huy khu vực")
// không thuộc đơn vị nào, không có khối/nhóm.
//
// Khi đổi mode → clear values của fields nhóm bị ẩn (để server nhận đúng null).
export default class extends Controller {
  static targets = ["mode", "unitGroup", "zoneGroup"]

  connect() {
    this.refresh()
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

  selectedMode() {
    const checked = this.modeTargets.find((r) => r.checked)
    return checked ? checked.value : "unit"
  }

  show(el) { el.classList.remove("hidden") }
  hide(el) { el.classList.add("hidden") }

  clearSelects(wrapper) {
    wrapper.querySelectorAll("select").forEach((s) => { s.value = "" })
  }
}
