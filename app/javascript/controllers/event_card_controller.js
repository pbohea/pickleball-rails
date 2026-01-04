import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  goToEvent(event) {
    // Prevent navigation if the click is on a link or button inside the card
    if (event.target.closest("a, button")) return
    window.Turbo.visit(this.urlValue)
  }
}
