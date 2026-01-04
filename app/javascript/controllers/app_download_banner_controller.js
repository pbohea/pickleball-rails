import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "app-download-banner-dismissed"
// For testing: always reappear (0ms window). Set back to 6 * 60 * 60 * 1000 for 6 hours.
const DISMISS_MS = 0

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.dismissed() ? this.hide() : this.activate()
  }

  dismiss() {
    this.storeDismissal()
    this.deactivate()
  }

  activate() {
    this.showBanner()
    this.hideNavbar()
    this.toggleBodyPadding(true)
  }

  deactivate() {
    this.showNavbar()
    this.toggleBodyPadding(false)
    this.hide()
  }

  hide() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("d-none")
    }
  }

  dismissed() {
    try {
      const stored = window.localStorage.getItem(STORAGE_KEY)
      if (!stored) return false

      const ts = parseInt(stored, 10)

      // If older format ("true") or unparsable, clear and treat as not dismissed
      if (Number.isNaN(ts)) {
        window.localStorage.removeItem(STORAGE_KEY)
        return false
      }

      return Date.now() - ts < DISMISS_MS
    } catch (error) {
      return false
    }
  }

  storeDismissal() {
    try {
      window.localStorage.setItem(STORAGE_KEY, Date.now().toString())
    } catch (error) {
      // Ignore storage errors (private mode, etc.)
    }
  }

  hideNavbar() {
    const nav = document.getElementById("main-navbar")
    if (nav) nav.classList.add("d-none")
  }

  showNavbar() {
    const nav = document.getElementById("main-navbar")
    if (nav) nav.classList.remove("d-none")
  }

  toggleBodyPadding(enable) {
    if (enable) {
      document.body.classList.add("app-banner-active")
    } else {
      document.body.classList.remove("app-banner-active")
    }
  }

  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("d-none")
    }
  }
}
