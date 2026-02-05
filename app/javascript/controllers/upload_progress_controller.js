import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "spinner", "label", "barWrap", "bar"]

  connect() {
    this.onStart = this.onStart.bind(this)
    this.onProgress = this.onProgress.bind(this)
    this.onEnd = this.onEnd.bind(this)
    this.onError = this.onError.bind(this)

    document.addEventListener("direct-upload:start", this.onStart)
    document.addEventListener("direct-upload:progress", this.onProgress)
    document.addEventListener("direct-upload:end", this.onEnd)
    document.addEventListener("direct-upload:error", this.onError)
  }

  disconnect() {
    document.removeEventListener("direct-upload:start", this.onStart)
    document.removeEventListener("direct-upload:progress", this.onProgress)
    document.removeEventListener("direct-upload:end", this.onEnd)
    document.removeEventListener("direct-upload:error", this.onError)
  }

  onStart() {
    this.show()
    this.setProgress(0)
    this.submitTarget.disabled = true
  }

  onProgress(event) {
    const progress = event.detail.progress || 0
    this.setProgress(progress)
  }

  onEnd() {
    this.setProgress(100)
    this.hide()
  }

  onError() {
    this.hide()
  }

  show() {
    this.spinnerTarget.classList.remove("d-none")
    this.labelTarget.classList.remove("d-none")
    this.barWrapTarget.classList.remove("d-none")
    this.barWrapTarget.setAttribute("aria-hidden", "false")
  }

  hide() {
    this.spinnerTarget.classList.add("d-none")
    this.labelTarget.classList.add("d-none")
    this.barWrapTarget.classList.add("d-none")
    this.barWrapTarget.setAttribute("aria-hidden", "true")
  }

  setProgress(value) {
    const pct = Math.max(0, Math.min(100, value))
    this.barTarget.style.width = `${pct}%`
    this.barTarget.setAttribute("aria-valuenow", pct.toString())
  }
}
