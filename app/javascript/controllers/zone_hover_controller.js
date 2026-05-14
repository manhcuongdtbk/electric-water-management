import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  enter(event) {
    const zoneId = event.currentTarget.dataset.zoneId
    this.zoneCell(zoneId)?.classList.add("bg-gray-50")
  }

  leave(event) {
    const zoneId = event.currentTarget.dataset.zoneId
    this.zoneCell(zoneId)?.classList.remove("bg-gray-50")
  }

  zoneCell(zoneId) {
    return this.element.querySelector(`[data-zone-cell="${zoneId}"]`)
  }
}
