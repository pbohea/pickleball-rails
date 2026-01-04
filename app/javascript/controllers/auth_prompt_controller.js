import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String }

  prompt(event) {
    event.preventDefault()
    
    // Use custom message if provided, otherwise use default
    const message = this.messageValue || "You need to sign in. Go to sign in page?"
    
    if (confirm(message)) {
      window.location.href = "/users/sign_in"
    }
  }
}








//tab switch version below



// import { Controller } from "@hotwired/stimulus"

// export default class extends Controller {
//   static values = { 
//     message: String
//   }

//   prompt(event) {
//     event.preventDefault()
    
//     // Check if we're in the native app
//     if (this.isNativeApp()) {
//       // Since bridge isn't connecting, use Turbo to visit the menu path
//       // This will trigger your NavigatorDelegate in iOS
//       this.switchToMenuTab()
//     } else {
//       // In web browser - use the original behavior
//       const message = this.messageValue || "You need to sign in. Go to sign in page?"
      
//       if (confirm(message)) {
//         window.location.href = "/users/sign_in"
//       }
//     }
//   }

//   isNativeApp() {
//     // Check for Hotwire Native iOS in the user agent
//     const userAgent = navigator.userAgent
//     return userAgent.includes("Hotwire Native iOS") || 
//            userAgent.includes("Turbo Native iOS")
//   }

//   switchToMenuTab() {
//     // Use Turbo to visit a special path that iOS will intercept
//     if (window.Turbo) {
//       window.Turbo.visit("/native/switch-tab/menu")
//     } else {
//       // Fallback to regular navigation
//       window.location.href = "/native/switch-tab/menu"
//     }
//   }
// }
