// app/javascript/controllers/artist_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "hidden",
    "details", "username", "imageContainer", "bio",
    "verification", "submitButton", "manualNameField"
  ]

  connect() {
    this.isSelecting = false
    this.searchTimeout = null

    if (this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.addEventListener("input", () => {
        if (typeof this.updateSubmitButton === "function") {
          this.updateSubmitButton()
        }
      })
    }
  }

  normalizeText(s) {
    if (!s) return ""
    return s
      .normalize("NFKD")
      .replace(/[\u2019\u2018\u2032]/g, "'") // curly → straight
      .replace(/[`\u00B4]/g, "'")            // backtick/acute → straight
      .replace(/\s+/g, " ")
      .trim()
  }

  search() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    if (this.isSelecting) return

    const raw = this.inputTarget.value || ""
    const query = this.normalizeText(raw)

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      this.hideDetails()
      return
    }

    this.searchTimeout = setTimeout(() => this.performSearch(query), 150)
  }

  performSearch(query) {
    if (this.isSelecting) return

    fetch(`/artists/search.json?query=${encodeURIComponent(query)}`)
      .then(r => r.ok ? r.json() : Promise.reject(r))
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
      li.textContent = "No matches"
      this.resultsTarget.appendChild(li)
      return
    }

    for (const artist of artists) {
      const li = document.createElement("li")
      li.classList.add("list-group-item", "list-group-item-action")
      li.style.cursor = "pointer"
      li.textContent = artist.username

      li.addEventListener("click", () => {
        this.selectArtist(artist.slug, artist.username, artist.image, artist.bio)
      })

      this.resultsTarget.appendChild(li)
    }
  }

  selectArtist(slug, username, image, bio) {
    this.isSelecting = true
    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    this.inputTarget.value = username
    if (this.hasHiddenTarget) this.hiddenTarget.value = slug

    this.resultsTarget.innerHTML = ""
    this.showDetails(username, image, bio)

    if (this.hasHiddenTarget) {
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    setTimeout(() => (this.isSelecting = false), 300)
  }

  showDetails(username, image, bio) {
    if (this.hasUsernameTarget) this.usernameTarget.textContent = username
    if (this.hasImageContainerTarget) {
      this.imageContainerTarget.innerHTML = ""
      const img = document.createElement("img")
      img.src = image || "https://via.placeholder.com/80"
      img.alt = "Artist photo"
      img.className = "rounded-circle"
      img.style.width = "80px"
      img.style.height = "80px"
      img.style.objectFit = "cover"
      this.imageContainerTarget.appendChild(img)
    }
    if (this.hasBioTarget) this.bioTarget.textContent = bio || "No bio available"
    if (this.hasDetailsTarget) this.detailsTarget.classList.remove("d-none")

    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.disabled = true
      this.manualNameFieldTarget.value = ""
      this.manualNameFieldTarget.placeholder = "Artist selected from database"
    }
    if (typeof this.updateSubmitButton === "function") this.updateSubmitButton()
  }

  hideDetails() {
    if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
      this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (this.hasManualNameFieldTarget) {
      this.manualNameFieldTarget.disabled = false
      this.manualNameFieldTarget.placeholder = "Enter artist name"
    }
    if (typeof this.updateSubmitButton === "function") this.updateSubmitButton()
  }

  disconnect() {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }
}
