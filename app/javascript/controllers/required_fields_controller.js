import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notes", "file", "submit"]

  connect() {
    this.update = this.update.bind(this)
    this.element.addEventListener("input", this.update)
    this.element.addEventListener("change", this.update)
    this.update()
  }

  disconnect() {
    this.element.removeEventListener("input", this.update)
    this.element.removeEventListener("change", this.update)
  }

  update() {
    const notesOk = this.hasNotesTarget && this.notesTarget.value.trim().length > 0
    const fileOk = this.fileSelected()
    const enabled = notesOk && fileOk
    this.submitTarget.disabled = !enabled
  }

  fileSelected() {
    if (this.hasFileTarget) {
      const fileInput = this.fileTarget
      if (fileInput.files.length > 0) return true
    }

    const hidden = this.element.querySelector('input[type="hidden"][name="video[original_video]"]')
    return hidden && hidden.value && hidden.value.trim().length > 0
  }
}
