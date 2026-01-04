import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.onSubmit = this.onSubmit.bind(this)
    this.element.addEventListener("submit", this.onSubmit, { once: true })
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit)
    if (this._timer) clearTimeout(this._timer)
  }

  onSubmit(e) {
    // Guard: if already submitting, stop
    if (this.submitting) { e.preventDefault(); return }
    this.submitting = true

    // Disable & show progress
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this._origText = this.buttonTarget.value || this.buttonTarget.innerText
      if (this.buttonTarget.value !== undefined) {
        this.buttonTarget.value = "Submitting…"
      } else {
        this.buttonTarget.innerText = "Submitting…"
      }
      this.buttonTarget.classList.add("disabled")
    }

    // Safety fallback: visible hint if navigation hasn’t occurred in 15s
    this._timer = setTimeout(() => {
      this._injectHint()
    }, 15000)
  }

  _injectHint() {
    // If we’re still on the page, show a gentle info note
    const note = document.createElement("div")
    note.className = "alert alert-info mt-3"
    note.textContent = "Still working… large files or slow networks can take a moment."
    this.element.appendChild(note)
  }
}
