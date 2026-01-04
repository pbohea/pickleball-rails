// app/javascript/controllers/owner_category_warning_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "warning"]
  static values = { 
    artistPerformanceType: String,
    artistUsername: String 
  }

  connect() {
    console.log("Owner category warning controller connected")
    
    // Initialize with passed values (for edit form) or set to null (for new form)
    this.selectedArtistPerformanceType = this.artistPerformanceTypeValue || null
    this.selectedArtistUsername = this.artistUsernameValue || null
    
    console.log("Initialized with:", {
      artistPerformanceType: this.selectedArtistPerformanceType,
      artistUsername: this.selectedArtistUsername
    })
    
    // Listen for artist selection changes (for new form)
    document.addEventListener('artist-selection-changed', (event) => {
      this.handleArtistSelectionChange(event.detail)
    })
  }

  disconnect() {
    document.removeEventListener('artist-selection-changed', this.handleArtistSelectionChange)
  }

  handleArtistSelectionChange(detail) {
    console.log("Artist selection changed:", detail)
    
    this.selectedArtistPerformanceType = detail.performanceType
    this.selectedArtistUsername = detail.artistUsername
    
    // Check category immediately after artist selection change
    this.checkCategory()
  }

  checkCategory() {
    if (!this.hasCategoryTarget || !this.hasWarningTarget) return
    
    const selectedCategory = this.categoryTarget.value
    
    console.log("Checking category:", {
      selectedCategory,
      artistPerformanceType: this.selectedArtistPerformanceType,
      artistUsername: this.selectedArtistUsername
    })
    
    // Show warning if:
    // 1. An artist is selected from database
    // 2. The category differs from the artist's performance type
    // 3. Both values are present
    if (this.selectedArtistPerformanceType && 
        selectedCategory && 
        selectedCategory !== this.selectedArtistPerformanceType) {
      this.showWarning()
    } else {
      this.hideWarning()
    }
  }

  showWarning() {
    if (this.hasWarningTarget && this.selectedArtistUsername) {
      this.warningTarget.textContent = `This differs from ${this.selectedArtistUsername}'s profile and will only apply to this event`
      this.warningTarget.classList.remove("d-none")
      console.log("Warning shown for artist:", this.selectedArtistUsername)
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.add("d-none")
      console.log("Warning hidden")
    }
  }
}
