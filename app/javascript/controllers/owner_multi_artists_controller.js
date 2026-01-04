// app/javascript/controllers/owner_multi_artists_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "container", "rows", "submitHelp", "lockHint"]
  static values  = {
    // Optional CSS class to visually lock the block (e.g., "opacity-50 pe-none")
    lockedClass: String,
    // On edit forms, set data-owner-multi-artists-primary-present-value="true"
    primaryPresent: { type: Boolean, default: false },
    // Max rows (pulled from data-multi-artists-max-value)
  }

  connect() {
    this.max = parseInt(this.element.dataset.multiArtistsMaxValue || "5", 10)

    // Watch primary artist inputs on CREATE form so we can unlock when ready
    const form = this.formEl()
    if (form) {
      ;[
        'input[name="event[artist_id]"]',                                 // DB-picked artist id
        '#artist_verification',                                           // DB-picked verified checkbox
        '[data-owner-artist-autocomplete-target="gateCheckbox"]',         // manual gate checkbox
        '[data-owner-artist-autocomplete-target="manualNameField"]'       // manual name input
      ].forEach(sel => {
        const el = form.querySelector(sel)
        if (el) {
          const evt = el.type === "checkbox" ? "change" : "input"
          el.addEventListener(evt, () => {
            this.lockUI(!this.primaryReady())
            this.updateSubmitButton()
          })
        }
      })
      ;[
        '[data-time-options-target="venue"]',
        '[data-owner-category-warning-target="category"]',
        '[data-time-options-target="date"]',
        '[data-time-options-target="startTime"]',
        '[data-time-options-target="endTime"]'
      ].forEach(sel => {
        const el = form.querySelector(sel)
        if (el) el.addEventListener('change', () => this.updateSubmitButton())
      })
    }

    // Make sure pre-rendered rows are wired (EDIT form)
    this.bindExistingRows()

    // Initial lock state
    this.lockUI(!this.primaryReady())

    // Initial evaluation
    this.updateSubmitButton()
  }

  // ---------- UI helpers ----------

  toggle() {
    if (!this.hasToggleTarget) return
    if (this.hasContainerTarget) {
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

    // Matches the markup used elsewhere in owner forms
    row.innerHTML = `
      <div class="d-flex justify-content-between align-items-center mb-2">
        <div>
          <strong>Artist ${idx + 1}</strong>
          <div class="form-check mt-1">
            <input class="form-check-input" type="checkbox"
                  data-action="owner-multi-artists#toggleManual" />
            <label class="form-check-label">Artist not on Pickleball</label>
          </div>
        </div>
        <button type="button"
                class="btn btn-sm btn-link text-danger"
                data-action="owner-multi-artists#removeRow">
          Remove
        </button>
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
    this.bindRow(row)
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

    // Clear the opposing inputs
    if (useManual) {
      const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
      const verify   = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
      const verified = row.querySelector('[data-inline-artist-autocomplete-target="verifiedField"]')
      if (hiddenId) hiddenId.value = ""
      if (verify)   verify.checked = false
      if (verified) verified.value = "0"
    } else {
      const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
      if (manualInput) manualInput.value = ""
    }

    this.updateSubmitButton()
  }

  // ---------- Core gating + explanations ----------

  updateSubmitButton() {
    const form = this.formEl()
    if (!form) return

    const submit =
      form.querySelector('[data-conflict-checker-target="submit"]') ||
      form.querySelector('[data-owner-artist-autocomplete-target="submitButton"]')
    if (!submit) return

    const reasons = []

    // Required global fields (venue/date/times/category). Verification gate is handled by primaryReady()
    const requiredChecks = [
      { sel: '[data-time-options-target="venue"]',     label: "Pick a venue" },
      { sel: '[data-owner-category-warning-target="category"]', label: "Choose a category" },
      { sel: '[data-time-options-target="date"]',      label: "Select a date" },
      { sel: '[data-time-options-target="startTime"]', label: "Select a start time" },
      { sel: '[data-time-options-target="endTime"]',   label: "Select an end time" }
    ]
    requiredChecks.forEach(({ sel, label }) => {
      const el = form.querySelector(sel)
      if (!el) return
      const isCheckbox = el.type === "checkbox"
      const ok = isCheckbox ? el.checked : (el.value || "").trim() !== ""
      if (!ok) reasons.push(label)
    })

    // Additional artists validity (only if toggled open)
    if (this.hasToggleTarget && this.toggleTarget.checked) {
      const rows = this.rowsTarget?.querySelectorAll(".border.rounded.p-2") || []
      rows.forEach((row, idx) => {
        const n = idx 
        const manualWrap = row.querySelector("[data-manual-wrapper]")
        const dbWrap     = row.querySelector("[data-db-wrapper]")
        if (!manualWrap || !dbWrap) return

        // Manual mode visible?
        if (!manualWrap.classList.contains("d-none")) {
          const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
          if (!manualInput || manualInput.value.trim() === "") {
            reasons.push(`Additional artist #${n}: enter a name`)
          }
        } else {
          // DB mode
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

    // Respect conflict checker's disabled state
    const disabledByConflict = submit.dataset.disabledByConflict === "1"
    if (disabledByConflict) reasons.unshift("Resolve schedule conflict at this venue/time")

    // On CREATE form, we also block if primary artist isn't set/verified yet
    // (On EDIT we allow immediately due to primaryPresentValue=true)
    if (!this.primaryReady()) {
      reasons.unshift("Choose a primary artist (pick + verify, or enter a manual name)")
    }

    const blocked = disabledByConflict || reasons.length > 0
    submit.disabled = blocked

    // Render helper
    const helpEl = this.globalHelpEl(form)
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

  // ---------- Internal helpers ----------

  formEl() {
    return this.element.closest("form")
  }

  globalHelpEl(form) {
    // Prefer a global container under the submit; fall back to a target if you add one
    return form.querySelector("[data-submit-help-global]") ||
           (this.hasSubmitHelpTarget ? this.submitHelpTarget : null)
  }

  primaryReady() {
    // If edit form told us a primary already exists, unlock immediately
    if (this.primaryPresentValue) return true

    // If rows already exist (edit with pre-rendered rows), allow unlock too
    if (this.hasRowsTarget && this.rowsTarget.children.length > 0) return true

    // CREATE form logic: DB pick + verified OR manual gate + name
    const form = this.formEl()
    if (!form) return false
    const dbId       = form.querySelector('input[name="event[artist_id]"]')?.value?.trim()
    const dbVerified = form.querySelector('#artist_verification')?.checked
    const manualName = form.querySelector('[data-owner-artist-autocomplete-target="manualNameField"]')?.value?.trim()
    const gateOn     = form.querySelector('[data-owner-artist-autocomplete-target="gateCheckbox"]')?.checked
    return (dbId && dbVerified) || (gateOn && manualName)
  }

  lockUI(lock) {
    // Disable the toggle and hide container while locked
    if (this.hasToggleTarget) this.toggleTarget.disabled = lock
    if (this.hasContainerTarget && lock) this.containerTarget.classList.add("d-none")

    // Optional lock styling
    const klass = this.lockedClassValue
    if (klass) this.element.classList.toggle(klass, lock)

    // Optional “locked” hint element if you add one
    if (this.hasLockHintTarget) this.lockHintTarget.classList.toggle("d-none", !lock)
  }

  bindExistingRows() {
    if (!this.hasRowsTarget) return
    const rows = this.rowsTarget.querySelectorAll(".border.rounded.p-2")
    rows.forEach(row => this.bindRow(row))
  }

  bindRow(row) {
    const verification = row.querySelector('[data-inline-artist-autocomplete-target="verification"]')
    if (verification) verification.addEventListener("change", () => this.updateSubmitButton())

    const hiddenId = row.querySelector('[data-inline-artist-autocomplete-target="hidden"]')
    if (hiddenId) hiddenId.addEventListener("change", () => this.updateSubmitButton())

    const manualInput = row.querySelector('[name="event[additional_manual_names][]"]')
    if (manualInput) manualInput.addEventListener("input", () => this.updateSubmitButton())

    const toggleManual = row.querySelector('input[type="checkbox"][data-action="owner-multi-artists#toggleManual"]')
    if (toggleManual) toggleManual.addEventListener("change", () => this.updateSubmitButton())
  }
}
