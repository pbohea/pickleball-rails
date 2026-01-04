// app/javascript/controllers/poll_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String, interval: Number }

  connect() {
    this.tick = this.tick.bind(this);
    this.timer = setInterval(this.tick, this.intervalValue || 5000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  tick() {
    const frame = this.element.querySelector("turbo-frame#batch");
    if (!frame) return;

    const status = frame.querySelector("[data-batch-status]")?.dataset.batchStatus;
    if (status && status !== "running") {
      clearInterval(this.timer); // stop polling once finished/failed
      return;
    }

    // Force a fresh fetch of the frame
    frame.src = `${this.urlValue}?t=${Date.now()}`;
  }
}
