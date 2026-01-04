// app/javascript/controllers/owner_artist_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "hidden", "details", "username", "imageContainer",
    "bio", "verification", "submitButton",
    "manualNameField", "manualConfirmation", // optional
    "gateCheckbox", "manualFieldsWrapper", "clearButton"
  ]

  connect() {
    console.log("owner-artist-autocomplete v4 connected")
    this.isSelecting = false
    this.searchTimeout = null
    this.manualConfirmationShown = false
    this.selectedArtistPerformanceType = null
    this.selectedArtistUsername = null
    this.ensureGatedState()
    this.updateClearButtonVisibility()

    if (this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.addEventListener("input", () => this.handleManualNameInput())
      this.manualNameFieldTarget.addEventListener("blur", () => this.handleManualNameBlur())
    }

    this.addFormFieldListeners()
    this.updateSubmitButton()
  }

  addFormFieldListeners() {
    const fieldsToWatch = [
      '[data-time-options-target="venue"]',
      '[data-owner-category-warning-target="category"]',
      '[data-time-options-target="date"]',
      '[data-time-options-target="startTime"]',
      '[data-time-options-target="endTime"]'
    ]

    fieldsToWatch.forEach(selector => {
      const element = document.querySelector(selector)
      if (element) {
        element.addEventListener('change', () => this.updateSubmitButton())
      }
    })
  }

  // --- utils ---
  normalizeText(s) {
    if (!s) return ""
    return s
      .normalize("NFKD")
      .replace(/[\u2019\u2018\u2032]/g, "'")
      .replace(/[`\u00B4]/g, "'")
      .replace(/\s+/g, " ")
      .trim()
  }

  // --- search ---
  search() {
    if (this.isSelecting) return
    if (this.hasGateCheckboxTarget && this.gateCheckboxTarget.checked) return // manual mode
    const raw = (this.inputTarget.value || "")
    const query = this.normalizeText(raw)
    this.updateClearButtonVisibility()

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      this.hideDetails()
      return
    }

    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.performSearch(query), 150)
  }

  performSearch(query) {
    if (this.isSelecting) return
    fetch(`/artists/search.json?query=${encodeURIComponent(query)}`)
      .then(r => (r.ok ? r.json() : Promise.reject(r)))
      .then(artists => this.displayResults(Array.isArray(artists) ? artists : []))
      .catch(err => {
        console.error("Artist search failed:", err)
        this.resultsTarget.innerHTML = ""
      })
  }

  displayResults(artists) {
    this.resultsTarget.innerHTML = ""

    if (artists.length === 0) {
      const li = document.createElement("li")
      li.className = "list-group-item text-muted"
      li.textContent = "No matches, this artist may not be on Pickleball"
      this.resultsTarget.appendChild(li)
      return
    }

    for (const artist of artists) {
      const li = document.createElement("li")
      li.classList.add("list-group-item", "list-group-item-action")
      li.style.cursor = "pointer"
      li.textContent = artist.username
      li.addEventListener("click", () => {
        this.selectArtist(artist.id, artist.username, artist.image, artist.bio, artist.performance_type)
      })
      this.resultsTarget.appendChild(li)
    }
  }

  clearSearch() {
    if (this.hasInputTarget) this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
    this.updateClearButtonVisibility()
    this.hideDetails()
    if (this.hasHiddenTarget) this.hiddenTarget.value = ""
    if (this.hasInputTarget) this.inputTarget.focus()
    this.updateSubmitButton()
  }

  updateClearButtonVisibility() {
    if (!this.hasClearButtonTarget || !this.hasInputTarget) return
    const hasText = (this.inputTarget.value || "").trim().length > 0
    this.clearButtonTarget.classList.toggle("invisible", !hasText)
    this.clearButtonTarget.classList.toggle("pe-none", !hasText)
  }

  // --- select artist from DB ---
  selectArtist(id, username, image, bio, performanceType) {
    this.isSelecting = true
    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    this.selectedArtistPerformanceType = performanceType
    this.selectedArtistUsername = username
    this.inputTarget.value = username
    if (this.hasHiddenTarget) this.hiddenTarget.value = id

    this.resultsTarget.innerHTML = ""

    if (this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.value = ""
      this.manualNameFieldTarget.disabled = true
      this.manualNameFieldTarget.placeholder = "Artist selected from database"
      this.manualNameFieldTarget.classList.add("bg-light", "text-muted")
    }

    this.showDetails(username, image, bio)
    this.notifyCategoryController()
    this.populateCategory(performanceType)

    setTimeout(() => (this.isSelecting = false), 100)
    this.updateSubmitButton()
  }

  showDetails(username, image, bio) {
    if (this.hasUsernameTarget) this.usernameTarget.textContent = username

    if (this.hasImageContainerTarget) {
      const placeholder = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22%3E%3Ccircle cx=%2250%22 cy=%2250%22 r=%2240%22 fill=%22%23ddd%22/%3E%3Ctext x=%2250%22 y=%2255%22 text-anchor=%22middle%22 font-size=%2220%22 fill=%22%23999%22%3ENo Photo%3C/text%3E%3C/svg%3E'
      const img = document.createElement("img")
      img.src = image || placeholder
      img.alt = "Artist photo"
      img.className = "rounded-circle"
      img.style.width = "80px"
      img.style.height = "80px"
      img.style.objectFit = "cover"
      this.imageContainerTarget.innerHTML = ""
      this.imageContainerTarget.appendChild(img)
    }

    if (this.hasBioTarget) this.bioTarget.textContent = bio || "No bio available"
    if (this.hasDetailsTarget) this.detailsTarget.classList.remove("d-none")
    if (this.hasVerificationTarget) this.verificationTarget.checked = false
  }

  hideDetails() {
    if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
    if (this.hasHiddenTarget) this.hiddenTarget.value = ""
    this.selectedArtistPerformanceType = null
    this.selectedArtistUsername = null
    this.notifyCategoryController()
    if (this.hasVerificationTarget) this.verificationTarget.checked = false

    if (this.hasManualNameFieldTarget && !(this.hasGateCheckboxTarget && this.gateCheckboxTarget.checked)) {
      this.manualNameFieldTarget.disabled = false
      this.manualNameFieldTarget.placeholder = "Enter artist name (ask them to join Pickleball!)"
      this.manualNameFieldTarget.classList.remove("bg-light", "text-muted")
    }

    this.updateSubmitButton()
  }

  // --- manual entry gate ---
  toggleGate() { this.ensureGatedState() }

  ensureGatedState() {
    const gated = this.hasGateCheckboxTarget ? this.gateCheckboxTarget.checked : false

    if (gated) {
      // Clear DB selection in manual mode (keep as-is)
      if (this.hasInputTarget) this.inputTarget.value = ""
      this.resultsTarget.innerHTML = ""
      if (this.hasHiddenTarget) this.hiddenTarget.value = ""
      if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
      if (this.hasVerificationTarget) this.verificationTarget.checked = false

      if (this.hasManualNameFieldTarget) {
        // ✨ do NOT overwrite existing value that the server rendered
        // If you really want to sanitize, only set placeholder & enable:
        // if (!this.manualNameFieldTarget.value.trim()) { /* optional defaulting */ }
        this.manualNameFieldTarget.disabled = false
        this.manualNameFieldTarget.placeholder = "Enter artist name (ask them to join Pickleball!)"
        this.manualNameFieldTarget.classList.remove("bg-light", "text-muted")
      }

      this.selectedArtistPerformanceType = null
      this.selectedArtistUsername = null
      this.notifyCategoryController(true)
    }

    if (this.hasManualFieldsWrapperTarget) {
      this.manualFieldsWrapperTarget.classList.toggle("d-none", !gated)
      const fields = this.manualFieldsWrapperTarget.querySelectorAll("input, select, textarea, button")
      fields.forEach(el => { el.disabled = !gated })
    }

    if (this.hasInputTarget) {
      this.inputTarget.disabled = gated
      this.inputTarget.classList.toggle("bg-light", gated)
      this.inputTarget.classList.toggle("text-muted", gated)
      this.inputTarget.placeholder = gated ? "Artist not on Pickleball" : "Start typing..."
    }

    if (!gated && this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.value = ""
      this.handleManualNameInput()
    }

    this.updateSubmitButton()
  }

  handleManualNameInput() {
    if (this.hasGateCheckboxTarget && this.gateCheckboxTarget.checked) {
      this.resultsTarget.innerHTML = ""
      this.hideDetails()
    }
    this.updateSubmitButton()
  }

  handleManualNameBlur() {
    // Optional hook
  }

  // --- submit gating ---
  toggleSubmit() { this.updateSubmitButton() }

  updateSubmitButton() {
    if (!this.hasSubmitButtonTarget) return

    // Respect the conflict checker if it has disabled the button
    if (this.submitButtonTarget.dataset.disabledByConflict === "1") return

    const gated = this.hasGateCheckboxTarget ? this.gateCheckboxTarget.checked : false

    // Picked-artist path
    const hasDBArtist = this.hasHiddenTarget && (this.hiddenTarget.value || "") !== ""
    const verified = this.hasVerificationTarget ? this.verificationTarget.checked : true

    // Manual path
    const hasManualName = this.hasManualNameFieldTarget && this.manualNameFieldTarget.value.trim().length > 0

    const artistValid = gated ? hasManualName : (hasDBArtist && verified)

    // Other required fields
    const venueValid = this.checkRequiredField('[data-time-options-target="venue"]')
    const categoryValid = this.checkRequiredField('[data-owner-category-warning-target="category"]')
    const dateValid = this.checkRequiredField('[data-time-options-target="date"]')
    const startTimeValid = this.checkRequiredField('[data-time-options-target="startTime"]')
    const endTimeValid = this.checkRequiredField('[data-time-options-target="endTime"]')

    const allValid = artistValid && venueValid && categoryValid && dateValid && startTimeValid && endTimeValid

    this.submitButtonTarget.disabled = !allValid
  }

  checkRequiredField(selector) {
    const element = document.querySelector(selector)
    if (!element) return true
    const value = element.value || ""
    return value.trim() !== ""
  }

  // --- category helpers ---
  populateCategory(performanceType) {
    if (!performanceType) return
    const select = document.querySelector("[data-owner-category-warning-target='category']")
    if (select && select.value !== performanceType) {
      select.value = performanceType
    }
  }

  notifyCategoryController(force = false) {
    if (!force && this.hasGateCheckboxTarget && this.gateCheckboxTarget.checked) return

    if (this.categoryNotificationTimeout) clearTimeout(this.categoryNotificationTimeout)

    this.categoryNotificationTimeout = setTimeout(() => {
      const evt = new CustomEvent("artist-selection-changed", {
        detail: {
          performanceType: this.selectedArtistPerformanceType,
          artistUsername: this.selectedArtistUsername
        }
      })
      document.dispatchEvent(evt)
    }, 50)
  }

  disconnect() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.categoryNotificationTimeout) clearTimeout(this.categoryNotificationTimeout)
  }
}
