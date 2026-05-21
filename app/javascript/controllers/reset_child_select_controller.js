import { Controller } from "@hotwired/stimulus"

// Reset child select về blank khi parent select thay đổi.
// Dùng cho cascading dropdown mà server sẽ render lại options sau submit.
export default class extends Controller {
  static targets = ["child"]

  reset() {
    this.childTargets.forEach((el) => { el.value = "" })
  }
}
