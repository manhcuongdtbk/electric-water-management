import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { storageKey: String }

  connect() {
    this.table = this.element.querySelector("table[data-billing-table]")
    if (!this.table) return
    this.applyStoredWidths()
    this.injectResizeHandles()
  }

  applyStoredWidths() {
    const widths = this.loadWidths()
    const ths = this.resizableHeaderCells()
    ths.forEach((th, idx) => {
      const w = widths[idx]
      if (w) th.style.width = `${w}px`
    })
  }

  resizableHeaderCells() {
    return Array.from(this.table.querySelectorAll("thead th"))
  }

  loadWidths() {
    if (!this.storageKeyValue) return {}
    try {
      return JSON.parse(localStorage.getItem(this.storageKeyValue) || "{}")
    } catch (_e) {
      return {}
    }
  }

  saveWidths(widths) {
    if (!this.storageKeyValue) return
    localStorage.setItem(this.storageKeyValue, JSON.stringify(widths))
  }

  injectResizeHandles() {
    this.resizableHeaderCells().forEach((th, idx) => {
      if (th.style.position !== "absolute") th.style.position = "relative"
      const handle = document.createElement("div")
      handle.className = "column-resize-handle"
      handle.style.position = "absolute"
      handle.style.top = "0"
      handle.style.right = "0"
      handle.style.bottom = "0"
      handle.style.width = "4px"
      handle.style.cursor = "col-resize"
      handle.style.userSelect = "none"
      handle.addEventListener("mousedown", (e) => this.startResize(e, th, idx))
      th.appendChild(handle)
    })
  }

  startResize(e, th, idx) {
    e.preventDefault()
    e.stopPropagation()
    const startX = e.clientX
    const startWidth = th.offsetWidth

    const onMove = (ev) => {
      const newWidth = Math.max(40, startWidth + (ev.clientX - startX))
      th.style.width = `${newWidth}px`
    }
    const onUp = () => {
      document.removeEventListener("mousemove", onMove)
      document.removeEventListener("mouseup", onUp)
      const widths = this.loadWidths()
      widths[idx] = th.offsetWidth
      this.saveWidths(widths)
    }
    document.addEventListener("mousemove", onMove)
    document.addEventListener("mouseup", onUp)
  }
}
