import { Controller } from "@hotwired/stimulus"

// When derived data is stale (data-stale="true"), intercept the Export-to-Excel
// click to confirm first. On confirm, append acknowledged_stale=1 and proceed.
export default class extends Controller {
  static values = { stale: Boolean, message: String, url: String }

  confirm(event) {
    if (!this.staleValue) return
    event.preventDefault()
    if (window.confirm(this.messageValue)) {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("acknowledged_stale", "1")
      window.location.href = url.toString()
    }
  }
}
