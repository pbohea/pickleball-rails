import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  static values = { max: Number }

  connect() {
    this.updateCount()
  }

  get textarea() {
    return this.element.querySelector('textarea')
  }

  updateCount() {
    const length = this.textarea.value.length
    this.countTarget.textContent = `${length}/${this.maxValue}`
    
    if (length > this.maxValue * 0.9) {
      this.countTarget.classList.add("text-warning")
    } else {
      this.countTarget.classList.remove("text-warning")
    }
    
    if (length >= this.maxValue) {
      this.countTarget.classList.add("text-danger")
      this.countTarget.classList.remove("text-warning")
    } else {
      this.countTarget.classList.remove("text-danger")
    }
  }

  input() {
    this.updateCount()
  }
}
