import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "addressInput","latInput","lngInput",
    "addressRadio","currentRadio",
    "locationButton","logo","label"
  ]
  static values = {
    currentLat: Number,
    currentLng: Number,
    currentAddress: String,
    currentRadius: Number
  }

  // Bind pageshow handler so it keeps "this"
  initialize() {
    this.handlePageShow = this.handlePageShow.bind(this)
  }

  connect() {
    console.log("=== LOCATION SEARCH CONTROLLER v2.1 LOADED ===")

    // Reset visuals on connect (covers Turbo reloads)
    this.resetButtonVisuals()

    // Reset again when page restored from bfcache/back button
    window.addEventListener("pageshow", this.handlePageShow)

    // Existing setup
    if (this.currentLatValue && this.currentLngValue) {
      this.latInputTarget.value = this.currentLatValue
      this.lngInputTarget.value = this.currentLngValue
    }

    this.addressInputTarget.addEventListener('input', () => {
      console.log("Address input changed, clearing coordinates")
      this.latInputTarget.value = ""
      this.lngInputTarget.value = ""
    })

    if (this.hasAddressRadioTarget && this.hasCurrentRadioTarget) {
      this.addressRadioTarget.addEventListener('change', () => {
        if (this.addressRadioTarget.checked) this.enableAddressMode()
      })
      this.currentRadioTarget.addEventListener('change', () => {
        if (this.currentRadioTarget.checked) this.enableLocationMode()
      })
    }
  }

  disconnect() {
    window.removeEventListener("pageshow", this.handlePageShow)
  }

  handlePageShow() {
    // Whether persisted or not, reset to be safe
    this.resetButtonVisuals()
  }

  resetButtonVisuals() {
    if (this.hasLogoTarget) {
      this.logoTarget.classList.remove("spin")
      this.logoTarget.classList.add("d-none")
    }
    if (this.hasLabelTarget) {
      this.labelTarget.classList.remove("d-none")
    }
    if (this.hasLocationButtonTarget) {
      this.locationButtonTarget.disabled = false
      this.locationButtonTarget.setAttribute("aria-busy", "false")
    }
  }

  enableAddressMode() {
    this.addressInputTarget.required = true
    this.addressInputTarget.focus()
    this.latInputTarget.value = ""
    this.lngInputTarget.value = ""
  }

  enableLocationMode() {
    this.addressInputTarget.required = false
    this.addressInputTarget.value = ""
  }

  // Replaces button label with spinning logo during geolocation, then submits
  useCurrentLocation(event) {
    const button = this.hasLocationButtonTarget ? this.locationButtonTarget : event.currentTarget.closest('button')
    const logo   = this.hasLogoTarget ? this.logoTarget : null
    const label  = this.hasLabelTarget ? this.labelTarget : null

    if (button && button.getAttribute("aria-busy") === "true") return

    if (!navigator.geolocation) {
      alert("Geolocation is not supported by your browser")
      return
    }

    // Enter loading state
    if (button) {
      button.disabled = true
      button.setAttribute("aria-busy", "true")
    }
    if (label) label.classList.add("d-none")
    if (logo)  { logo.classList.remove("d-none"); logo.classList.add("spin") }

    const resetButton = () => {
      if (logo)  { logo.classList.remove("spin"); logo.classList.add("d-none") }
      if (label) label.classList.remove("d-none")
      if (button) {
        button.disabled = false
        button.setAttribute("aria-busy", "false")
      }
    }

    const timeoutId = setTimeout(() => {
      resetButton()
      alert("Location request timed out. Please try again or enter an address manually.")
    }, 10000)

    const options = { enableHighAccuracy: true, timeout: 8000, maximumAge: 300000 }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        clearTimeout(timeoutId)

        const lat = position.coords.latitude
        const lng = position.coords.longitude

        this.latInputTarget.value = lat
        this.lngInputTarget.value = lng
        this.addressInputTarget.value = ""

        this.reverseGeocode(lat, lng)
          .then(address => {
            if (address) {
              this.addressInputTarget.value = address
            } else {
              this.addressInputTarget.value = `${lat.toFixed(4)}, ${lng.toFixed(4)}`
            }
          })
          .catch(() => {
            this.addressInputTarget.value = `${lat.toFixed(4)}, ${lng.toFixed(4)}`
          })
          .finally(() => {
            // Do NOT reset here before submit to avoid blink
            this.submitForm()
          })
      },
      (error) => {
        clearTimeout(timeoutId)
        resetButton()

        let message = "Unable to get your location. "
        switch (error.code) {
          case error.PERMISSION_DENIED:    message += "Location access was denied, change location permissions in settings."; break
          case error.POSITION_UNAVAILABLE: message += "Location information is unavailable."; break
          case error.TIMEOUT:              message += "Location request timed out."; break
          default:                         message += "An unknown error occurred."
        }
        alert(message + " Please enter an address manually.")
      },
      options
    )
  }

  getCurrentLocation() {
    this.addressInputTarget.required = false

    if (!navigator.geolocation) {
      alert("Geolocation is not supported by your browser")
      this.enableAddressMode()
      if (this.hasAddressRadioTarget) this.addressRadioTarget.checked = true
      return
    }

    const options = { enableHighAccuracy: true, timeout: 8000, maximumAge: 300000 }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude
        const lng = position.coords.longitude

        this.latInputTarget.value = lat
        this.lngInputTarget.value = lng

        this.reverseGeocode(lat, lng)
          .then(address => {
            this.addressInputTarget.value = address || `${lat.toFixed(4)}, ${lng.toFixed(4)}`
          })
          .catch(() => {
            this.addressInputTarget.value = `${lat.toFixed(4)}, ${lng.toFixed(4)}`
          })
      },
      (error) => {
        this.enableAddressMode()
        if (this.hasAddressRadioTarget) this.addressRadioTarget.checked = true

        let message = "Unable to get your location. "
        switch (error.code) {
          case error.PERMISSION_DENIED:    message += "Location access was denied."; break
          case error.POSITION_UNAVAILABLE: message += "Location information is unavailable."; break
          case error.TIMEOUT:              message += "Location request timed out."; break
          default:                         message += "An unknown error occurred."
        }
        alert(message + " Please enter an address manually.")
      },
      options
    )
  }

  submitForm() {
    try {
      this.element.requestSubmit()
    } catch {
      try {
        this.element.submit()
      } catch {
        const submitButton = this.element.querySelector('input[type="submit"]')
        if (submitButton) submitButton.click()
      }
    }
  }

  async reverseGeocode(lat, lng) {
    try {
      const res = await fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lng}&localityLanguage=en`)
      if (!res.ok) throw new Error(res.status)
      const data = await res.json()
      const parts = []
      if (data.locality) parts.push(data.locality)
      if (data.principalSubdivision) parts.push(data.principalSubdivision)
      if (data.postcode) parts.push(data.postcode)
      return parts.length ? parts.join(", ") : null
    } catch {
      return null
    }
  }

  autoSubmit() {
    this.element.requestSubmit()
  }

  validateLocation(event) {
    const addressInput = this.addressInputTarget.value.trim()
    const latInput = this.latInputTarget.value
    const lngInput = this.lngInputTarget.value
    const errorDiv = document.getElementById('location-error')

    if (!addressInput && (!latInput || !lngInput)) {
      event.preventDefault()
      if (errorDiv) errorDiv.classList.remove('d-none')
      this.addressInputTarget.focus()
      return false
    }
    if (errorDiv) errorDiv.classList.add('d-none')
    return true
  }
}
