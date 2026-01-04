// app/javascript/controllers/time_options_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["venue", "date", "startTime", "endTime"]

  connect() {
    // When editing, try to preload everything
    this.updateDateOptions().then(() => {
      this.applyDefault(this.dateTarget)
      this.updateStartTimes()
    })
  }

  venueChanged() {
    this.updateDateOptions()
    this.clearTimeOptions()
  }

  updateStartTimes() {
    const venueSlug = (this.venueTarget?.value || "").trim()
    const selectedDate = (this.dateTarget?.value || "").trim()
    if (venueSlug && selectedDate) {
      this.fetchStartTimes(venueSlug, selectedDate)
    } else {
      this.clearTimeOptions()
    }
  }

  updateEndTimes() {
    const venueSlug = (this.venueTarget?.value || "").trim()
    const selectedDate = (this.dateTarget?.value || "").trim()
    const selectedStartTime = (this.startTimeTarget?.value || "").trim()

    // 🔹 Clear end immediately to avoid conflict checks with stale end
    this.clearEndTimeOptions(true) // true => dispatch change event

    if (venueSlug && selectedDate && selectedStartTime) {
      this.fetchEndTimes(venueSlug, selectedDate, selectedStartTime)
    }
  }

  async updateDateOptions() {
    const venueSlug = (this.venueTarget?.value || "").trim()
    if (!venueSlug) return
    try {
      const url = `/events/date_options_ajax?venue_slug=${encodeURIComponent(venueSlug)}`
      const res = await fetch(url, { headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" } })
      if (res.ok) {
        const data = await res.json()
        this.populateDateOptions(data.date_options)
      }
    } catch (e) {
      console.error("Error fetching date options:", e)
    }
  }

  populateDateOptions(dates) {
    this.dateTarget.innerHTML = '<option value="">Select date</option>'
    dates.forEach(([display, value]) => this.dateTarget.add(new Option(display, value)))
    this.applyDefault(this.dateTarget)
    this.clearTimeOptions()
  }

  async fetchStartTimes(venueSlug, selectedDate) {
    try {
      const url = `/events/time_options_ajax?venue_slug=${encodeURIComponent(venueSlug)}&date=${encodeURIComponent(selectedDate)}`
      const res = await fetch(url, { headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" } })
      if (res.ok) {
        const data = await res.json()
        // Server now handles time filtering, so we just populate all returned times
        this.populateStartTimes(data.start_times)
        this.clearEndTimeOptions(true) // also notify listeners that end cleared
      }
    } catch (e) {
      console.error("Error fetching start time options:", e)
    }
  }

  async fetchEndTimes(venueSlug, selectedDate, selectedStartTime) {
    try {
      const url = `/events/end_time_options_ajax?venue_slug=${encodeURIComponent(venueSlug)}&date=${encodeURIComponent(selectedDate)}&start_time=${encodeURIComponent(selectedStartTime)}`
      const res = await fetch(url, { headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" } })
      if (res.ok) {
        const data = await res.json()
        this.populateEndTimes(data.end_times)
      }
    } catch (e) {
      console.error("Error fetching end time options:", e)
    }
  }

  populateStartTimes(times) {
    this.startTimeTarget.innerHTML = '<option value="">Select start time</option>'

    // Server handles all time filtering now - just populate all returned times
    times.forEach(([display, value]) => {
      this.startTimeTarget.add(new Option(display, value))
    })

    // Apply default and auto-trigger end times
    const defVal = this.startTimeTarget.dataset.defaultValue
    if (defVal) {
      this.startTimeTarget.value = defVal
      if (this.startTimeTarget.value === defVal) {
        this.updateEndTimes()
      }
    }
  }

  populateEndTimes(times) {
    this.endTimeTarget.innerHTML = '<option value="">Select end time</option>'
    times.forEach(([display, value]) => this.endTimeTarget.add(new Option(display, value)))

    // Apply default if present; otherwise pick first valid option
    const defVal = this.endTimeTarget.dataset.defaultValue
    if (defVal && Array.from(this.endTimeTarget.options).some(o => o.value === defVal)) {
      this.endTimeTarget.value = defVal
    } else if (this.endTimeTarget.options.length > 1) {
      this.endTimeTarget.selectedIndex = 1
    }

    // 🔹 Programmatic selection doesn't fire change — fire it so conflict-checker re-runs
    this.dispatchChange(this.endTimeTarget)
  }

  clearTimeOptions() {
    this.clearStartTimeOptions()
    this.clearEndTimeOptions(true) // notify listeners (clears any conflict banner)
  }

  clearStartTimeOptions() {
    this.startTimeTarget.innerHTML = '<option value="">Select start time</option>'
  }

  clearEndTimeOptions(emitChange = false) {
    this.endTimeTarget.innerHTML = '<option value="">Select end time</option>'
    if (emitChange) this.dispatchChange(this.endTimeTarget)
  }

  // Helper: auto-select option if data-default-value matches
  applyDefault(selectEl) {
    if (!selectEl) return
    const defVal = selectEl.dataset.defaultValue
    if (defVal) {
      const option = Array.from(selectEl.options).find(opt => opt.value === defVal)
      if (option) option.selected = true
    }
  }

  // Helper: reliably emit 'change' for programmatic value updates
  dispatchChange(el) {
    if (!el) return
    el.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
