import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "video-upload"
  static targets = ["notes"]
  static values = {
    uploadUrl: String,
    csrfToken: String
  }

  capture() {
    if (!this.enabled) {
      return
    }

    const notes = this.hasNotesTarget ? this.notesTarget.value : ""
    const payload = {
      uploadUrl: this.uploadUrlValue,
      notes,
      csrfToken: this.csrfTokenValue
    }

    this.send("capture", payload, (message) => {
      const data = message?.data || {}
      if (data.redirect_url) {
        window.Turbo.visit(data.redirect_url)
      } else if (data.error) {
        alert(data.error)
      }
    })
  }
}
