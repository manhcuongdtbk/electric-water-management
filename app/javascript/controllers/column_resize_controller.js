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
      if (w) {
        th.style.minWidth = `${w}px`
        th.style.maxWidth = `${w}px`
      }
    })
  }

  resizableHeaderCells() {
    // Header có 3 hàng merge (colspan/rowspan). Chỉ lấy các th thực sự
    // chiếm cột dữ liệu — tức các th chạm đến hàng cuối cùng của thead.
    const rows = Array.from(this.table.querySelectorAll("thead tr"))
    if (rows.length === 0) return []

    const lastRowIndex = rows.length - 1
    const result = []

    rows.forEach((tr, rowIndex) => {
      Array.from(tr.children).forEach((th) => {
        const rowspan = parseInt(th.getAttribute("rowspan") || "1", 10)
        // Th chạm hàng cuối nếu: rowIndex + rowspan - 1 >= lastRowIndex
        if (rowIndex + rowspan - 1 >= lastRowIndex) {
          result.push(th)
        }
      })
    })

    return result
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
      // Không chèn handle vào th có colspan (nhóm cột, không phải cột dữ liệu)
      const colspan = parseInt(th.getAttribute("colspan") || "1", 10)
      if (colspan > 1) return

      th.style.position = "relative"
      const handle = document.createElement("div")
      handle.className = "column-resize-handle"
      handle.style.position = "absolute"
      handle.style.top = "0"
      handle.style.right = "0"
      handle.style.bottom = "0"
      handle.style.width = "6px"
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
      th.style.minWidth = `${newWidth}px`
      th.style.maxWidth = `${newWidth}px`
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
