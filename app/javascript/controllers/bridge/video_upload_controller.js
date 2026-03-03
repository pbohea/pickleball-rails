import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "video-upload"
  static targets = ["notes", "analysisStart", "analysisEnd"]
  static values = {
    uploadUrl: String,
    csrfToken: String
  }

  capture() {
    if (!this.enabled) {
      return
    }

    const notes = this.hasNotesTarget ? this.notesTarget.value : ""
    const analysisStart = this.hasAnalysisStartTarget ? this.analysisStartTarget.value : ""
    const analysisEnd = this.hasAnalysisEndTarget ? this.analysisEndTarget.value : ""
    const payload = {
      uploadUrl: this.uploadUrlValue,
      notes,
      analysis_start: analysisStart,
      analysis_end: analysisEnd,
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
