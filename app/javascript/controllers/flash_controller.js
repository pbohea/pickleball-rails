import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    setTimeout(() => {
      this.element.classList.remove("show"); // triggers Bootstrap fade
      setTimeout(() => this.element.remove(), 300); // remove after fade
    }, this.timeoutValue || 5000); // fallback to 3s
  }
}
