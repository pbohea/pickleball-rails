// app/javascript/controllers/nav_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  go(event) {
    if (event.target.closest("a")) return
    window.location = this.urlValue
  }
}
