import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

export default class extends Controller {
  static targets = ["input", "preview", "saveButton"]

  connect() {
    this.cropper = null
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)
    this.isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    this.isCropping = false
  }

  previewImage(event) {
    const file = event.target.files[0]
    if (!file || !file.type.startsWith("image/")) return

    this.resetSaveButton()
    this.enableCroppingMode()

    const reader = new FileReader()

    reader.onload = () => {
      this.previewTarget.src = reader.result
      this.previewTarget.classList.remove("d-none")

      const initializeCropper = () => {
        if (this.cropper && typeof this.cropper.destroy === "function") {
          this.cropper.destroy()
        }

        // iOS and touch-optimized configuration
        const cropperConfig = {
          aspectRatio: 1,
          viewMode: 1,
          autoCropArea: 0.8, // Slightly smaller initial crop area for easier handling
          responsive: true,
          background: false,
          modal: true,
          guides: this.isTouchDevice ? false : true, // Disable guides on touch devices
          highlight: false,
          cropBoxResizable: true,
          cropBoxMovable: true,
          dragMode: "move",
          scalable: true, // Enable scaling for pinch-to-zoom
          zoomable: true, // Enable zooming
          wheelZoomRatio: 0.1,
          touchDragZoom: this.isTouchDevice, // Enable touch drag zoom on mobile
          minCropBoxWidth: 50,
          minCropBoxHeight: 50,
          crop: () => {
            this.updateLivePreview()
            this.resetSaveButton()
            // Re-enable cropping mode if they adjust the crop after saving
            if (!this.isCropping) {
              this.enableCroppingMode()
            }
          },
          ready: () => {
            // Additional iOS optimizations after cropper is ready
            if (this.isIOS) {
              this.optimizeForIOS()
            }
          }
        }

        this.cropper = new Cropper(this.previewTarget, cropperConfig)
        this.saveButtonTarget.classList.remove("d-none")

        // Prevent iOS Safari zoom on double tap
        if (this.isIOS) {
          this.preventIOSZoom()
        }
      }

      if (this.previewTarget.complete && this.previewTarget.naturalWidth !== 0) {
        initializeCropper()
      } else {
        this.previewTarget.onload = initializeCropper
      }
    }

    reader.readAsDataURL(file)
  }

  enableCroppingMode() {
    this.isCropping = true
    this.disableFormFields()
    this.showCroppingMessage()
  }

  disableCroppingMode() {
    this.isCropping = false
    this.enableFormFields()
    this.hideCroppingMessage()
  }

  disableFormFields() {
    // Find all form inputs, selects, textareas, and buttons except the cropper-related ones
    const form = this.element.closest('form')
    if (!form) return

    const fieldsToDisable = form.querySelectorAll('input:not([data-cropper-target]), select, textarea, button[type="submit"]')
    
    fieldsToDisable.forEach(field => {
      field.disabled = true
      field.classList.add('cropping-disabled')
    })

    // Add visual styling for disabled state
    const style = document.createElement('style')
    style.id = 'cropping-disabled-styles'
    style.textContent = `
      .cropping-disabled {
        opacity: 0.5 !important;
        background-color: #f8f9fa !important;
        cursor: not-allowed !important;
      }
      .cropping-disabled:focus {
        box-shadow: none !important;
      }
    `
    document.head.appendChild(style)
  }

  enableFormFields() {
    // Re-enable all form fields
    const form = this.element.closest('form')
    if (!form) return

    const fieldsToEnable = form.querySelectorAll('.cropping-disabled')
    
    fieldsToEnable.forEach(field => {
      field.disabled = false
      field.classList.remove('cropping-disabled')
    })

    // Remove the disabled styling
    const style = document.getElementById('cropping-disabled-styles')
    if (style) {
      style.remove()
    }
  }

  showCroppingMessage() {
    // Create and show a message about cropping mode
    const existingMessage = document.getElementById('cropping-message')
    if (existingMessage) return

    const message = document.createElement('div')
    message.id = 'cropping-message'
    message.className = 'alert alert-info d-flex align-items-center mb-3'
    message.innerHTML = `
      <i class="fas fa-crop-alt me-2"></i>
      <span>Crop your image and click <strong>Save</strong> to continue editing the form</span>
    `

    // Insert the message at the top of the form
    const form = this.element.closest('form')
    const firstChild = form.querySelector('.mb-3, .row')
    if (firstChild) {
      firstChild.parentNode.insertBefore(message, firstChild)
    }
  }

  hideCroppingMessage() {
    const message = document.getElementById('cropping-message')
    if (message) {
      message.remove()
    }
  }

  optimizeForIOS() {
    const cropperContainer = this.previewTarget.parentElement.querySelector('.cropper-container')
    if (!cropperContainer) return

    // Improve touch handling for iOS
    cropperContainer.style.touchAction = 'manipulation'
    
    // Add better visual feedback for touch interactions
    const cropBox = cropperContainer.querySelector('.cropper-crop-box')
    if (cropBox) {
      cropBox.style.cursor = 'move'
      cropBox.style.touchAction = 'none'
      
      // Add touch feedback
      cropBox.addEventListener('touchstart', () => {
        cropBox.style.opacity = '0.8'
      }, { passive: true })
      
      cropBox.addEventListener('touchend', () => {
        cropBox.style.opacity = '1'
      }, { passive: true })
    }

    // Optimize drag handles for touch
    const handles = cropperContainer.querySelectorAll('.cropper-point')
    handles.forEach(handle => {
      handle.style.width = '16px'
      handle.style.height = '16px'
      handle.style.opacity = '0.8'
      handle.style.backgroundColor = '#007bff'
      handle.style.border = '2px solid white'
      handle.style.borderRadius = '50%'
      handle.style.touchAction = 'none'
    })

    // Make corner handles more prominent
    const cornerHandles = cropperContainer.querySelectorAll('.cropper-point.point-se, .cropper-point.point-nw, .cropper-point.point-ne, .cropper-point.point-sw')
    cornerHandles.forEach(handle => {
      handle.style.width = '20px'
      handle.style.height = '20px'
      handle.style.backgroundColor = '#0056b3'
    })
  }

  preventIOSZoom() {
    const cropperContainer = this.previewTarget.parentElement.querySelector('.cropper-container')
    if (!cropperContainer) return

    // Prevent double-tap zoom on the cropper
    let lastTouchEnd = 0
    cropperContainer.addEventListener('touchend', (e) => {
      const now = (new Date()).getTime()
      if (now - lastTouchEnd <= 300) {
        e.preventDefault()
      }
      lastTouchEnd = now
    }, { passive: false })

    // Prevent pinch zoom on the document when interacting with cropper
    let isInteracting = false
    
    cropperContainer.addEventListener('touchstart', () => {
      isInteracting = true
    }, { passive: true })
    
    cropperContainer.addEventListener('touchend', () => {
      setTimeout(() => { isInteracting = false }, 100)
    }, { passive: true })

    document.addEventListener('touchmove', (e) => {
      if (isInteracting && e.touches.length > 1) {
        e.preventDefault()
      }
    }, { passive: false })
  }

  cropAndReplace() {
    if (!this.cropper || typeof this.cropper.getCroppedCanvas !== "function") {
      alert("Please wait for the image to load before saving.")
      return
    }

    // Show loading state for better UX
    const originalText = this.saveButtonTarget.textContent
    this.saveButtonTarget.textContent = "Processing..."
    this.saveButtonTarget.disabled = true

    // Use setTimeout to allow UI to update
    setTimeout(() => {
      try {
        const canvas = this.cropper.getCroppedCanvas({
          width: 160,
          height: 160,
          imageSmoothingEnabled: true,
          imageSmoothingQuality: "high"
        })

        canvas.toBlob(blob => {
          if (!blob) {
            alert("Failed to crop image.")
            this.saveButtonTarget.textContent = originalText
            this.saveButtonTarget.disabled = false
            return
          }

          const uniqueFilename = `artist_${Date.now()}.jpg`
          const file = new File([blob], uniqueFilename, { type: "image/jpeg" })

          const dataTransfer = new DataTransfer()
          dataTransfer.items.add(file)
          this.inputTarget.files = dataTransfer.files

          const previewEl = document.getElementById("cropper-preview-result")
          const labelEl = document.getElementById("cropped-preview-label")

          if (previewEl && labelEl) {
            previewEl.src = URL.createObjectURL(blob)
            previewEl.classList.remove("d-none")
            labelEl.classList.remove("d-none")
          }

          this.markAsSaved()
          this.disableCroppingMode() // Re-enable form fields after saving
        }, "image/jpeg", 0.9) // Slightly higher quality for better results
      } catch (error) {
        console.error("Error cropping image:", error)
        alert("Error processing image. Please try again.")
        this.saveButtonTarget.textContent = originalText
        this.saveButtonTarget.disabled = false
      }
    }, 10)
  }

  updateLivePreview() {
    if (!this.cropper || typeof this.cropper.getCroppedCanvas !== "function") return

    // Debounce the preview update for better performance on mobile
    if (this.previewTimeout) {
      clearTimeout(this.previewTimeout)
    }

    this.previewTimeout = setTimeout(() => {
      try {
        const canvas = this.cropper.getCroppedCanvas({
          width: 120,
          height: 120,
          imageSmoothingEnabled: true,
          imageSmoothingQuality: "high"
        })

        const previewEl = document.getElementById("cropper-preview-result")
        const labelEl = document.getElementById("cropped-preview-label")

        if (canvas && previewEl && labelEl) {
          canvas.toBlob(blob => {
            if (!blob) return

            // Clean up previous URL to prevent memory leaks
            if (previewEl.src && previewEl.src.startsWith('blob:')) {
              URL.revokeObjectURL(previewEl.src)
            }

            const url = URL.createObjectURL(blob)
            previewEl.src = url
            previewEl.classList.remove("d-none")
            labelEl.classList.remove("d-none")
          }, "image/jpeg", 0.8)
        }
      } catch (error) {
        console.error("Error updating preview:", error)
      }
    }, 100) // Debounce by 100ms
  }

  markAsSaved() {
    this.saveButtonTarget.textContent = "Saved!"
    this.saveButtonTarget.classList.remove("btn-outline-primary")
    this.saveButtonTarget.classList.add("btn-success")
    this.saveButtonTarget.disabled = false
  }

  resetSaveButton() {
    this.saveButtonTarget.textContent = "Confirm photo to continue"
    this.saveButtonTarget.classList.remove("btn-success")
    this.saveButtonTarget.classList.add("btn-outline-primary")
    this.saveButtonTarget.disabled = false
  }

  disconnect() {
    // Clean up when controller is disconnected
    if (this.cropper && typeof this.cropper.destroy === "function") {
      this.cropper.destroy()
    }
    if (this.previewTimeout) {
      clearTimeout(this.previewTimeout)
    }
    this.enableFormFields() // Ensure fields are enabled if component is destroyed
    this.hideCroppingMessage()
  }
}
