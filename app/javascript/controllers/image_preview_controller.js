import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "container"]

  previewImage() {
    const file = this.inputTarget.files[0]
    if (!file) {
      this.containerTarget.classList.add("d-none")
      this.previewTarget.src = ""
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.src = e.target.result
      this.containerTarget.classList.remove("d-none")
    }
    reader.readAsDataURL(file)
  }
}
