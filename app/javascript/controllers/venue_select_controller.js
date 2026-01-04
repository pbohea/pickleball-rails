import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["box"];

  all()  { this.boxTargets.forEach(cb => cb.checked = true); }
  none() { this.boxTargets.forEach(cb => cb.checked = false); }
}
