import { Controller } from "@hotwired/stimulus"

// Khi user đổi <select> loại đầu mối → reload page với `?type=NEW_TYPE`
// để backend render đúng sub-form tương ứng.
// Sub-forms khác nhau theo loại (residential/public có Đơn vị-Khu vực;
// water_pump/non_establishment chỉ Khu vực, ...) — không thể toggle bằng JS.
export default class extends Controller {
  static values = { param: { type: String, default: "type" } }

  redirect(event) {
    const value = event.target.value
    if (!value) return
    const url = new URL(window.location.href)
    url.searchParams.set(this.paramValue, value)
    window.location.href = url.toString()
  }
}
