// app/javascript/controllers/multi_artists_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "container", "rows", "submitHelp"]

  connect() {
    this.max = parseInt(this.element.dataset.multiArtistsMaxValue || "5", 10)

    const form = this.element.closest("form")
    if (form) {
      // Common required fields we observe for gating/explanations
      ;[
        '[data-time-options-target="venue"]',
        '[data-artist-category-warning-target="category"]',
        '[data-owner-category-warning-target="category"]',
        '[data-time-options-target="date"]',
        '[data-time-options-target="startTime"]',
        '[data-time-options-target="endTime"]',
        '#venue_verification'
      ].forEach(sel => {
        const el = form.querySelector(sel)
        if (!el) return
        el.addEventListener("change", () => this.updateSubmitButton())
        el.addEventListener("input",  () => this.updateSubmitButton())
      })
    }

    // Make sure pre-rendered rows are wired (edit case)
    this.bindExistingRows()
    this.updateSubmitButton()
  }

  bindExistingRows() {
    if (!this.hasRowsTarget) return
    const rows = this.rowsTarget.querySelectorAll(".border.rounded.p-2")
    rows.forEach(row => {
      const verification = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
      if (verification) verification.addEventListener("change", () => this.updateSubmitButton())

      const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
      if (hiddenId) hiddenId.addEventListener("change", () => this.updateSubmitButton())

      const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
      if (manualInput) manualInput.addEventListener("input", () => this.updateSubmitButton())

      const toggleManual = row.querySelector('input[type="checkbox"][data-action="multi-artists#toggleManual"]')
      if (toggleManual) toggleManual.addEventListener("change", () => this.updateSubmitButton())
    })
  }

  // UI helpers

  toggle() {
    if (this.hasContainerTarget && this.hasToggleTarget) {
      this.containerTarget.classList.toggle("d-none", !this.toggleTarget.checked)
    }
    this.updateSubmitButton()
  }

  addRow() {
    if (!this.hasRowsTarget) return
    if (this.rowsTarget.children.length >= this.max) return

    const idx = this.rowsTarget.children.length + 1
    const row = document.createElement("div")
    row.className = "border rounded p-2 mb-2 bg-white"

    row.innerHTML = `
      <div class="d-flex justify-content-between align-items-center mb-2">
        <strong>Artist ${idx+1}</strong>
        <button type="button" class="btn btn-sm btn-link text-danger" data-action="multi-artists#removeRow">Remove</button>
      </div>

      <div class="mb-2 form-check">
        <input class="form-check-input" type="checkbox" data-action="multi-artists#toggleManual" />
        <label class="form-check-label">Artist not on Pickleball</label>
      </div>

      <!-- DB pick -->
      <div class="mb-2" data-db-wrapper>
        <div class="position-relative" data-controller="inline-artist-autocomplete">
          <input type="text" class="form-control pe-5" placeholder="Search artist..."
                 data-inline-artist-autocomplete-target="input" autocomplete="off" />
          <ul class="list-group small mt-1 position-absolute w-100"
              data-inline-artist-autocomplete-target="results"
              style="z-index:1000; max-height:200px; overflow:auto;"></ul>

          <input type="hidden" name="event[additional_artist_ids][]"
                 data-inline-artist-autocomplete-target="hidden" />

          <div class="border border-info rounded p-2 bg-info-subtle mt-2 d-none"
               data-inline-artist-autocomplete-target="details">
            <div class="d-flex align-items-start gap-2">
              <div class="flex-shrink-0" data-inline-artist-autocomplete-target="imageContainer"></div>
              <div class="flex-grow-1">
                <p class="mb-1"><strong>Username:</strong>
                  <span data-inline-artist-autocomplete-target="username"></span>
                </p>
                <p class="mb-0 text-muted small" data-inline-artist-autocomplete-target="bio"></p>
              </div>
            </div>

            <div class="form-check mt-2">
              <input type="hidden" name="event[additional_artist_verified][]" value="0"
                     data-inline-artist-autocomplete-target="verifiedField">
              <input class="form-check-input" type="checkbox"
                     data-inline-artist-autocomplete-target="verification">
              <label class="form-check-label"><strong>Yes, this is the correct artist for my event</strong></label>
            </div>
          </div>
        </div>
      </div>

      <!-- Manual entry -->
      <div class="mb-2 d-none" data-manual-wrapper>
        <input type="text" class="form-control"
               name="event[additional_manual_names][]" placeholder="Enter artist name" />
      </div>
    `

    this.rowsTarget.appendChild(row)

    // Bind listeners for the new row
    const verification = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
    if (verification) verification.addEventListener("change", () => this.updateSubmitButton())

    const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
    if (hiddenId) hiddenId.addEventListener("change", () => this.updateSubmitButton())

    const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
    if (manualInput) manualInput.addEventListener("input", () => this.updateSubmitButton())

    this.updateSubmitButton()
  }

  removeRow(event) {
    event.currentTarget.closest(".border.rounded.p-2").remove()
    this.updateSubmitButton()
  }

  toggleManual(event) {
    const row = event.currentTarget.closest(".border.rounded.p-2")
    const dbWrap = row.querySelector("[data-db-wrapper]")
    const manualWrap = row.querySelector("[data-manual-wrapper]")

    const useManual = event.currentTarget.checked
    if (manualWrap) manualWrap.classList.toggle("d-none", !useManual)
    if (dbWrap) dbWrap.classList.toggle("d-none", useManual)

    // Clear opposing inputs
    if (useManual) {
      const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
      const verify    = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
      const verified  = row.querySelector('[data-inline-artist-autocomplete-target="verifiedField"]')
      if (hiddenId) hiddenId.value = ""
      if (verify) verify.checked = false
      if (verified) verified.value = "0"
    } else {
      const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
      if (manualInput) manualInput.value = ""
    }

    this.updateSubmitButton()
  }

  // Core gating + explanation

  updateSubmitButton() {
    const form = this.element.closest("form")
    const submit =
      form?.querySelector('[data-conflict-checker-target="submit"]') ||
      form?.querySelector('[data-venue-autocomplete-target="submitButton"]')
    if (!submit) return

    const reasons = []

    // Required global fields
    const requiredChecks = [
      { sel: '[data-time-options-target="venue"]',     label: "Pick a venue" },
      { sel: '[data-artist-category-warning-target="category"]', label: "Choose a category" },
      { sel: '[data-owner-category-warning-target="category"]',  label: "Choose a category" },
      { sel: '[data-time-options-target="date"]',      label: "Select a date" },
      { sel: '[data-time-options-target="startTime"]', label: "Select a start time" },
      { sel: '[data-time-options-target="endTime"]',   label: "Select an end time" },
      { sel: '#venue_verification',                    label: "Confirm the venue is correct" }
    ]
    requiredChecks.forEach(({ sel, label }) => {
      const el = form?.querySelector(sel)
      if (!el) return
      const isCheckbox = el.type === "checkbox"
      const ok = isCheckbox ? el.checked : (el.value || "").trim() !== ""
      if (!ok) reasons.push(label)
    })

    // Additional artists validity
    if (this.hasToggleTarget && this.toggleTarget.checked) {
      const rows = this.rowsTarget.querySelectorAll(".border.rounded.p-2")
      rows.forEach((row, idx) => {
        const n = idx + 1
        const manualWrap = row.querySelector("[data-manual-wrapper]")
        const dbWrap     = row.querySelector("[data-db-wrapper]")

        if (!manualWrap || !dbWrap) return

        if (!manualWrap.classList.contains("d-none")) {
          const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
          if (!manualInput || manualInput.value.trim() === "") {
            reasons.push(`Additional artist #${n}: enter a name`)
          }
        } else {
          const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
          const verify   = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
          if (!hiddenId || hiddenId.value === "") {
            reasons.push(`Additional artist #${n}: pick an artist`)
          } else if (!verify || !verify.checked) {
            reasons.push(`Additional artist #${n}: confirm the artist is correct`)
          }
        }
      })
    }

    // Respect conflict checker’s disable state
    const disabledByConflict = submit.dataset.disabledByConflict === "1"
    if (disabledByConflict) reasons.unshift("Resolve schedule conflict at this venue/time")

    const blocked = disabledByConflict || reasons.length > 0
    submit.disabled = blocked

    // Global helper under the submit button
    const helpEl = form?.querySelector("[data-submit-help]") || (this.hasSubmitHelpTarget ? this.submitHelpTarget : null)
    if (helpEl) {
      if (blocked) {
        helpEl.innerHTML = `<ul class="mb-0 ps-3">${reasons.map(r => `<li>${r}</li>`).join("")}</ul>`
        helpEl.parentElement?.classList?.remove("d-none")
      } else {
        helpEl.innerHTML = ""
        helpEl.parentElement?.classList?.add("d-none")
      }
    }
  }
}
