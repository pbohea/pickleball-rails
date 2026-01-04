// app/javascript/controllers/artist_category_warning_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "warning"]
  static values = { 
    artistPerformanceType: String,
    isEdit: Boolean 
  }

  connect() {
    console.log("Artist category warning controller connected")
    console.log("Artist performance type:", this.artistPerformanceTypeValue)
    console.log("Is edit form:", this.isEditValue)
    
    // Only set initial category to artist's performance type for NEW events (not edit)
    if (!this.isEditValue && this.artistPerformanceTypeValue && this.hasCategoryTarget) {
      this.categoryTarget.value = this.artistPerformanceTypeValue
    }
    
    // Check if already different on page load
    this.checkCategory()
  }

  checkCategory() {
    if (!this.hasCategoryTarget || !this.hasWarningTarget) return
    
    const selectedCategory = this.categoryTarget.value
    const artistPerformanceType = this.artistPerformanceTypeValue
    
    console.log("Checking category:", { selectedCategory, artistPerformanceType })
    
    // Show warning if category differs from artist's performance type
    if (selectedCategory && artistPerformanceType && selectedCategory !== artistPerformanceType) {
      this.showWarning()
    } else {
      this.hideWarning()
    }
  }

  showWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.remove("d-none")
      console.log("Warning shown")
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.add("d-none")
      console.log("Warning hidden")
    }
  }
}
