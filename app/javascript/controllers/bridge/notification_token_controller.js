import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Connects to data-controller="bridge--notification-token"
export default class extends BridgeComponent {
  static component = "notification-token"

  connect() {
    super.connect()
    this.send("connect")
  }
}
