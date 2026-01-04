// app/javascript/controllers/venue_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "hidden",
    "details", "name", "address",
    "verification", "submitButton"
  ]

  connect() {
    this.isSelecting = false
    this.searchTimeout = null
  }

  // Called on input (debounced). No preventDefault / scroll hacks.
  search() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.isSelecting) return

    const query = (this.inputTarget.value || "").trim()

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.searchTimeout = setTimeout(() => this.performSearch(query), 150)
  }

  performSearch(query) {
    if (this.isSelecting) return

    fetch(`/venues/search?query=${encodeURIComponent(query)}`)
      .then((r) => r.ok ? r.json() : Promise.reject(r))
      .then((venues) => this.displayResults(Array.isArray(venues) ? venues : []))
      .catch((err) => {
        console.error("Venue search failed:", err)
        this.resultsTarget.innerHTML = ""
      })
  }

  displayResults(venues) {
    const isClaimPage = window.location.pathname.includes("/claim")
    this.resultsTarget.innerHTML = ""

    if (venues.length === 0) {
      const li = document.createElement("li")
      li.className = "list-group-item text-muted"
      li.textContent = "No matches"
      this.resultsTarget.appendChild(li)
      return
    }

    for (const venue of venues) {
      const li = document.createElement("li")
      li.classList.add("list-group-item", "list-group-item-action")
      li.style.cursor = "pointer"
      li.textContent = `${venue.name} — ${venue.city}`

      const slug = venue.slug
      const name = venue.name
      const address = this.formatAddress(venue)

      li.addEventListener("click", () => {
        if (isClaimPage) {
          this.selectVenueForClaim(slug, name, address)
        } else {
          this.selectVenue(slug, name, address)
        }
      })

      this.resultsTarget.appendChild(li)
    }
  }

  // Selection for normal flows (store slug)
  selectVenue(slug, name, address) {
    this.isSelecting = true
    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    // Fill visible & hidden fields
    this.inputTarget.value = name
    if (this.hasHiddenTarget) this.hiddenTarget.value = slug

    // Clear dropdown
    this.resultsTarget.innerHTML = ""

    // Show details if those targets exist
    this.showDetails(name, address)

    // Notify anyone watching the hidden field
    if (this.hasHiddenTarget) {
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    // Re-enable searching shortly after
    setTimeout(() => (this.isSelecting = false), 300)
  }

  // Claim page flow (guard against already-owned venue)
  selectVenueForClaim(slug, name, address) {
    this.isSelecting = true
    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    fetch(`/venues/${encodeURIComponent(slug)}/check_ownership`)
      .then((r) => r.ok ? r.json() : Promise.reject(r))
      .then((data) => {
        if (data?.has_owner) {
          this.showOwnershipAlert()
          setTimeout(() => this.clearSelection(), 100)
        } else {
          this.selectVenue(slug, name, address)
        }
      })
      .catch((err) => {
        console.warn("Ownership check failed (continuing):", err)
        this.selectVenue(slug, name, address)
      })
      .finally(() => setTimeout(() => (this.isSelecting = false), 300))
  }

  showDetails(name, address) {
    if (this.hasNameTarget) this.nameTarget.textContent = name
    if (this.hasAddressTarget) this.addressTarget.textContent = address
    if (this.hasDetailsTarget) this.detailsTarget.classList.remove("d-none")

    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (typeof this.updateSubmitButton === "function") this.updateSubmitButton()
  }

  hideDetails() {
    if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (typeof this.updateSubmitButton === "function") this.updateSubmitButton()
  }

  clearSelection() {
    if (this.hasInputTarget) this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
    this.isSelecting = false
  }

  toggleSubmit() {
    if (this.hasSubmitButtonTarget && this.hasVerificationTarget && this.hasHiddenTarget) {
      const venueSelected = (this.hiddenTarget.value || "") !== ""
      const verified = this.verificationTarget.checked
      this.submitButtonTarget.disabled = !(venueSelected && verified)
    }
  }

  formatAddress(venue) {
    const parts = [venue.street_address, venue.city, venue.state, venue.zip_code].filter(Boolean)
    return parts.join(", ")
  }

  showOwnershipAlert() {
    const existing = document.querySelector(".venue-ownership-alert")
    if (existing) existing.remove()

    const html = `
      <div class="venue-ownership-alert" style="
        position: fixed; top: 80px; left: 50%; transform: translateX(-50%);
        z-index: 9999; background-color: #fff3cd; border: 2px solid #ffc107;
        border-radius: 8px; padding: 15px 20px; box-shadow: 0 4px 12px rgba(0,0,0,.3);
        max-width: 500px; width: 90%;
      ">
        <div style="display:flex;justify-content:space-between;align-items:flex-start;">
          <div>
            <strong style="color:#856404;">Venue Unavailable</strong><br>
            <span style="color:#856404;">This venue already has an owner and cannot be claimed.
            Please contact <a href="mailto:admin@pickleball.co" style="color:#856404;text-decoration:underline;">
            admin@pickleball.co</a> to dispute ownership.</span>
          </div>
          <button onclick="this.parentElement.parentElement.remove()" style="
            background:none;border:none;font-size:20px;cursor:pointer;color:#856404;margin-left:10px;">
            &times;
          </button>
        </div>
      </div>
    `
    document.body.insertAdjacentHTML("afterbegin", html)
  }

  disconnect() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }
}
