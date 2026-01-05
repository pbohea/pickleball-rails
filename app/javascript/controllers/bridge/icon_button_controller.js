import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "icon-button"
  static values = {
    systemName: String,
    url: String
  }

  connect() {
    super.connect()

    const systemName = this.systemNameValue
    const url = this.urlValue

    this.send("connect", { systemName, url }, (message) => {
      const data = message?.data || {}
      const targetUrl = data.url || url
      if (targetUrl) {
        window.Turbo.visit(targetUrl)
      }
    })
  }
}
