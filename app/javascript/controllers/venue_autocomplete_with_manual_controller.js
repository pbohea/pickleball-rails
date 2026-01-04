// app/javascript/controllers/venue_autocomplete_with_manual_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    owner: Boolean,
    claimUrl: String
  }

  static targets = [
    "input", "results", "hidden",
    // kept for compatibility, but no longer used for inline panel:
    "details", "name", "address", "website", "websiteWrap",
    "gateCheckbox", "manualFieldsWrapper", "submitButton",
    "clearButton"
  ]

  connect() {
    console.log("venue-autocomplete-with-manual connected. owner?", this.ownerValue)
    this.clearResults()
    this.ensureGatedState()
    this.updateClearButtonVisibility()
  }

  /* ----------------------------------------
   * Search & results
   * -------------------------------------- */
  search() {
    this.updateClearButtonVisibility()

    const q = this.inputTarget.value.trim()
    if (q.length < 2) {
      this.clearResults()
      // Clear any selected slug
      if (this.hasHiddenTarget) {
        this.hiddenTarget.value = ""
        this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
      }
      return
    }

    fetch(`/venues/search?query=${encodeURIComponent(q)}`)
      .then(r => r.json())
      .then(data => this.renderResults(data || []))
      .catch(err => {
        console.error("Search error:", err)
        this.clearResults()
      })
  }

  renderResults(venues) {
    this.resultsTarget.innerHTML = ""
    venues.forEach(v => {
      const li = document.createElement("li")
      li.className = "list-group-item list-group-item-action"
      li.style.cursor = "pointer"
      li.innerHTML = `
        <div class="d-flex flex-column">
          <strong>${this.escapeHTML(v.name)}</strong>
          <small class="text-muted">${this.escapeHTML(this.formatAddress(v))}</small>
        </div>
      `
      li.addEventListener("click", () => this.onResultClick(v))
      this.resultsTarget.appendChild(li)
    })
  }

  clearResults() {
    if (this.hasResultsTarget) this.resultsTarget.innerHTML = ""
  }

  formatAddress(venue) {
    const parts = [venue.street_address, venue.city, venue.state, venue.zip_code].filter(Boolean)
    return parts.join(", ")
  }

  /* ----------------------------------------
   * Click a result → floating alerts for BOTH roles
   * -------------------------------------- */
  onResultClick(venue) {
    const slug = venue.slug
    const name = venue.name
    const address = this.formatAddress(venue)
    const website = venue.website || ""

    // Save for alert/detail rendering
    this.selectedVenue = { slug, name, address, website }

    if (this.ownerValue) {
      // Owners: check ownership then show alert with claim/owned messages
      this.checkOwnership(slug)
    } else {
      // Artists: show alert with Yes/No actions
      this.showArtistAlert()
    }
  }

  /* ----------------------------------------
   * ARTIST floating alert (replaces inline panel)
   * -------------------------------------- */
  showArtistAlert() {
    const details = this.buildVenueDetailsHTML(this.selectedVenue)
    this.showFloatingAlert(`
      ${details}
      <div style="margin-top:8px;">
        <div class="mb-2"><strong>Is this the venue you're trying to add?</strong></div>
        <div class="d-flex gap-2">
          <button type="button" id="artist-yes" class="btn btn-sm btn-primary">Yes</button>
          <button type="button" id="artist-no" class="btn btn-sm btn-outline-secondary">No, this isn’t the right venue</button>
        </div>
      </div>
    `, () => {
      const yes = document.getElementById("artist-yes")
      const no  = document.getElementById("artist-no")
      if (yes) yes.addEventListener("click", () => {
        this.removeFloatingAlert()
        if (this.selectedVenue?.slug) {
          window.location.href = `/venues/${encodeURIComponent(this.selectedVenue.slug)}`
        }
      })
      if (no) no.addEventListener("click", () => {
        this.removeFloatingAlert()
        this.checkGateAndRevealForm()
      })
    })
  }

  /* ----------------------------------------
   * OWNER ownership flow (floating alerts)
   * -------------------------------------- */
  checkOwnership(slug) {
    fetch(`/venues/${encodeURIComponent(slug)}/check_ownership`)
      .then(r => r.json())
      .then(data => {
        const details = this.buildVenueDetailsHTML(this.selectedVenue)
        if (data && data.has_owner) {
          this.showFloatingAlert(`
            ${details}
            <div style="margin-top:8px;">
              <strong style="color:#856404;">Venue Already Owned</strong><br>
              <span style="color:#856404;">
                This venue exists and is already owned. If this is a mistake, please email
                <a href="mailto:admin@pickleball.co" style="color:#856404;text-decoration:underline;">admin@pickleball.co</a>.
              </span>
            </div>
          `)
        } else {
          this.showFloatingAlert(`
            ${details}
            <div style="margin-top:8px;">
              <strong style="color:#0f5132;">Venue Found</strong><br>
              <span style="color:#0f5132;">
                This venue already exists in our database.
                <a href="${this.claimUrlValue}" style="text-decoration:underline;">Claim ownership here</a>.
              </span>
              <div class="mt-2">
                <button type="button" id="owner-not-right" class="btn btn-sm btn-outline-secondary">This isn’t the right venue</button>
              </div>
            </div>
          `, () => {
            const btn = document.getElementById("owner-not-right")
            if (btn) btn.addEventListener("click", () => {
              this.removeFloatingAlert()
              this.checkGateAndRevealForm()
            })
          })
        }
      })
      .catch(err => {
        console.error("Ownership check failed:", err)
        const details = this.buildVenueDetailsHTML(this.selectedVenue)
        this.showFloatingAlert(`
          ${details}
          <div style="margin-top:8px;">
            <strong style="color:#0f5132;">Venue Found</strong><br>
            <span style="color:#0f5132;">
              This venue may already exist.
              <a href="${this.claimUrlValue}" style="text-decoration:underline;">Claim ownership here</a>.
            </span>
            <div class="mt-2">
              <button type="button" id="owner-not-right" class="btn btn-sm btn-outline-secondary">This isn’t the right venue</button>
            </div>
          </div>
        `, () => {
          const btn = document.getElementById("owner-not-right")
          if (btn) btn.addEventListener("click", () => {
            this.removeFloatingAlert()
            this.checkGateAndRevealForm()
          })
        })
      })
  }

  /* ----------------------------------------
   * Clear button (×) behavior
   * -------------------------------------- */
  clearSearch() {
    if (this.hasInputTarget) this.inputTarget.value = ""
    this.updateClearButtonVisibility()
    this.clearResults()
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.removeFloatingAlert()
    if (this.hasInputTarget) this.inputTarget.focus()
  }

  updateClearButtonVisibility() {
    if (!this.hasClearButtonTarget || !this.hasInputTarget) return
    const hasText = this.inputTarget.value.trim().length > 0
    this.clearButtonTarget.classList.toggle("invisible", !hasText)
    this.clearButtonTarget.classList.toggle("pe-none", !hasText)
  }

  /* ----------------------------------------
   * Gate (checkbox) logic
   * -------------------------------------- */
  toggleGate() {
    this.ensureGatedState()
  }

  checkGateAndRevealForm() {
    if (this.hasGateCheckboxTarget && !this.gateCheckboxTarget.checked) {
      this.gateCheckboxTarget.checked = true
    }
    this.ensureGatedState()
  }

  ensureGatedState() {
    const checked = this.hasGateCheckboxTarget ? this.gateCheckboxTarget.checked : false

    if (this.hasManualFieldsWrapperTarget) {
      this.manualFieldsWrapperTarget.classList.toggle("d-none", !checked)
      const fields = this.manualFieldsWrapperTarget.querySelectorAll("input, select, textarea, button")
      fields.forEach(el => { el.disabled = !checked })
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !checked
    }
  }

  /* ----------------------------------------
   * UI helpers (floating alert)
   * -------------------------------------- */
  showFloatingAlert(innerHTML, afterInsertCallback = null) {
    this.removeFloatingAlert()

    const wrapper = document.createElement("div")
    wrapper.className = "venue-alert-wrapper"
    wrapper.style.position = "fixed"
    wrapper.style.top = "80px"
    wrapper.style.left = "50%"
    wrapper.style.transform = "translateX(-50%)"
    wrapper.style.zIndex = "9999"
    wrapper.style.backgroundColor = "#fff"
    wrapper.style.border = "2px solid #ffc107"
    wrapper.style.borderRadius = "8px"
    wrapper.style.padding = "15px 20px"
    wrapper.style.boxShadow = "0 4px 12px rgba(0,0,0,0.3)"
    wrapper.style.maxWidth = "600px"
    wrapper.style.width = "92%"

    wrapper.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:flex-start;">
        <div style="font-size:0.95rem;">${innerHTML}</div>
        <button type="button" aria-label="Close"
          style="background:none;border:none;font-size:20px;cursor:pointer;margin-left:10px;"
          data-role="close-alert">&times;</button>
      </div>
    `
    document.body.insertAdjacentElement("afterbegin", wrapper)

    const closeBtn = wrapper.querySelector('[data-role="close-alert"]')
    if (closeBtn) closeBtn.addEventListener("click", () => this.removeFloatingAlert())

    if (afterInsertCallback) afterInsertCallback()
  }

  removeFloatingAlert() {
    const existing = document.querySelector(".venue-alert-wrapper")
    if (existing) existing.remove()
  }

  /* ----------------------------------------
   * Venue detail block for alerts
   * -------------------------------------- */
  buildVenueDetailsHTML(venue) {
    if (!venue) return ""
    const name = this.escapeHTML(venue.name || "")
    const address = this.escapeHTML(venue.address || "")
    const slug = venue.slug ? encodeURIComponent(venue.slug) : ""
    const viewUrl = slug ? `/venues/${slug}` : null
    const website = venue.website ? this.safeUrl(venue.website) : null

    return `
      <div style="margin-bottom:8px;">
        <div><strong>${name}</strong></div>
        ${address ? `<div class="text-muted">${address}</div>` : ""}
        <div style="margin-top:4px;">
          ${website ? `<a href="${website}" target="_blank" rel="noopener">Website</a> · ` : ""}
          ${viewUrl ? `<a href="${viewUrl}" target="_blank" rel="noopener">View venue</a>` : ""}
        </div>
      </div>
    `
  }

  /* ----------------------------------------
   * Misc helpers
   * -------------------------------------- */
  safeUrl(u) {
    if (!u) return ""
    const trimmed = String(u).trim()
    if (/^https?:\/\//i.test(trimmed)) return trimmed
    return `http://${trimmed}`
  }

  escapeHTML(str) {
    return (str || "").replace(/[&<>"']/g, m => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[m]))
  }
}
