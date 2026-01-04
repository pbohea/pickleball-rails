// app/javascript/controllers/conflict_checker_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["venue", "venueId", "date", "startTime", "endTime", "flash", "submit", "excludeId"]
  static values = {
    endpoint: { type: String, default: "/events/conflicts_ajax" },
    disableOnly: { type: Boolean, default: false }
  }

  connect() { this.check() }

  async check() {
    const venueSlug = this.hasVenueTarget ? this.venueTarget.value?.trim() : ""
    const venueId   = this.hasVenueIdTarget ? this.venueIdTarget.value?.trim() : ""
    const date      = this.hasDateTarget ? this.dateTarget.value?.trim() : ""
    const start     = this.hasStartTimeTarget ? this.startTimeTarget.value?.trim() : ""
    const end       = this.hasEndTimeTarget ? this.endTimeTarget.value?.trim() : ""
    const excludeId = this.hasExcludeIdTarget ? this.excludeIdTarget.value?.trim() : ""

    // Require end time to avoid "+3h default" false positives
    if (!(venueSlug || venueId) || !date || !start || !end) {
      this.clearFlash()
      this.enableSubmitRespectingGates()
      return
    }

    const params = new URLSearchParams()
    if (venueSlug) params.set("venue_slug", venueSlug)
    if (venueId)   params.set("venue_id", venueId)
    params.set("date", date)
    params.set("start_time", start)
    params.set("end_time", end)
    if (excludeId) params.set("exclude_id", excludeId)

    try {
      const res = await fetch(`${this.endpointValue}?${params.toString()}`, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()
      if (data.ok && data.conflicts?.length) {
        this.showFlash(data.conflicts)
        this.disableSubmit()
      } else {
        this.clearFlash()
        this.enableSubmitRespectingGates()
      }
    } catch (e) {
      console.error("Conflict check failed:", e)
      this.clearFlash()
      this.enableSubmitRespectingGates()
    }
  }

  // Hooks from forms
  venueChanged()     { this.check() }
  dateChanged()      { this.check() }
  startTimeChanged() { this.check() }
  endTimeChanged()   { this.check() }

  // --- UI helpers ---
  showFlash(conflicts) {
    if (!this.hasFlashTarget) return
    const lines = conflicts.map(c => {
      const text = `${c.artist_name || "Event"} (${c.start_time}–${c.end_time}) at ${c.venue}`
      return `• ${c.url ? `<a href="${c.url}" target="_blank" class="text-decoration-underline text-blue fw-semibold">${text}</a>` : text}`
    }).join("<br>")
    this.flashTarget.innerHTML = `
      <div class="alert alert-danger rounded-3 py-2 px-3 mb-2">
        <strong>Conflict:</strong> another event is scheduled in this time window.
        <div class="mt-1 small">${lines}</div>
      </div>
    `
  }
  clearFlash() { if (this.hasFlashTarget) this.flashTarget.innerHTML = "" }

  disableSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = true
    this.submitTarget.dataset.disabledByConflict = "1"
  }

  enableSubmitRespectingGates() {
    if (!this.hasSubmitTarget) return

    // On edit forms, we own the button entirely.
    if (!this.disableOnlyValue) {
      this.submitTarget.disabled = false
      delete this.submitTarget.dataset.disabledByConflict
      return
    }

    // In disableOnly mode (create forms), only re-enable if WE disabled it
    // AND one of the allowed gates is satisfied.
    if (this.submitTarget.dataset.disabledByConflict === "1") {
      const venueVerified   = !!document.getElementById("venue_verification")?.checked     // artist create
      const artistVerified  = !!document.getElementById("artist_verification")?.checked    // owner create (picked)
      const manualGateOK    =
        !!document.getElementById("artist_gate_checkbox")?.checked &&
        ((document.getElementById("manual_artist_name")?.value?.trim()?.length || 0) >= 2) // owner create (manual)

      if (venueVerified || artistVerified || manualGateOK) {
        this.submitTarget.disabled = false
        delete this.submitTarget.dataset.disabledByConflict
      }
    }
  }
}
