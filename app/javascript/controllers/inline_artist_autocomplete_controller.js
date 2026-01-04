import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "hidden",
    // NEW:
    "details", "username", "imageContainer", "bio",
    "verification", "verifiedField"
  ]

  connect() {
    this.isSelecting = false
    this.searchTimeout = null
    this.onInput = this.onInput.bind(this)
    this.inputTarget.addEventListener("input", this.onInput)

    // Hook verification checkbox if present
    if (this.hasVerificationTarget && this.hasVerifiedFieldTarget) {
      this.verificationTarget.addEventListener("change", () => {
        this.verifiedFieldTarget.value = this.verificationTarget.checked ? "1" : "0"
      })
    }
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.onInput)
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
  }

  onInput() {
    if (this.isSelecting) return
    const q = (this.inputTarget.value || "").trim()
    this.resultsTarget.innerHTML = ""
    if (q.length < 2) return

    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.search(q), 150)
  }

  search(q) {
    if (this.isSelecting) return
    fetch(`/artists/search.json?query=${encodeURIComponent(q)}`)
      .then(r => (r.ok ? r.json() : Promise.reject(r)))
      .then(list => this.render(list || []))
      .catch(() => (this.resultsTarget.innerHTML = ""))
  }

  render(artists) {
    this.resultsTarget.innerHTML = ""
    if (!artists.length) {
      const li = document.createElement("li")
      li.className = "list-group-item text-muted"
      li.textContent = "No matches"
      this.resultsTarget.appendChild(li)
      return
    }
    artists.forEach(a => {
      const li = document.createElement("li")
      li.className = "list-group-item list-group-item-action"
      li.style.cursor = "pointer"
      li.textContent = a.username
      li.addEventListener("click", () => this.pick(a))
      this.resultsTarget.appendChild(li)
    })
  }

  pick(artist) {
    this.isSelecting = true
    this.inputTarget.value = artist.username
    this.hiddenTarget.value = artist.id
    this.resultsTarget.innerHTML = ""

    // Show details + reset verification
    if (this.hasDetailsTarget) this.detailsTarget.classList.remove("d-none")
    if (this.hasUsernameTarget) this.usernameTarget.textContent = artist.username || ""
    if (this.hasBioTarget) this.bioTarget.textContent = artist.bio || "No bio available"
    if (this.hasImageContainerTarget) {
      const img = document.createElement("img")
      img.src = artist.image || "https://via.placeholder.com/80"
      img.alt = "Artist photo"
      img.className = "rounded-circle"
      img.style.width = "64px"
      img.style.height = "64px"
      img.style.objectFit = "cover"
      this.imageContainerTarget.innerHTML = ""
      this.imageContainerTarget.appendChild(img)
    }
    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (this.hasVerifiedFieldTarget) this.verifiedFieldTarget.value = "0"

    setTimeout(() => (this.isSelecting = false), 100)
  }

  // When user clears/changes input, hide details & reset verification
  clearDetails() {
    if (this.hasDetailsTarget) this.detailsTarget.classList.add("d-none")
    if (this.hasVerificationTarget) this.verificationTarget.checked = false
    if (this.hasVerifiedFieldTarget) this.verifiedFieldTarget.value = "0"
    this.hiddenTarget.value = ""
  }

  onInput() {
    if (this.isSelecting) return
    const q = (this.inputTarget.value || "").trim()
    if (q.length < 2) {
      this.resultsTarget.innerHTML = ""
      this.clearDetails()
      return
    }
    if (this.searchTimeout) clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.search(q), 150)
  }
}
