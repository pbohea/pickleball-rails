import { Controller } from "@hotwired/stimulus";

// Submits its form when a child input changes (e.g., <select>)
export default class extends Controller {
  submit(event) {
    // If placed on the form, we can submit the form directly.
    // If placed on an element inside a form, walk up to the form.
    const form = this.element.tagName === "FORM" ? this.element : this.element.closest("form");
    if (form) form.requestSubmit ? form.requestSubmit() : form.submit();
  }
}
