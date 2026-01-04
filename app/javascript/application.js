// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Change to true to allow Turbo
Turbo.session.drive = true

// Allow UJS alongside Turbo
import jquery from "jquery";
window.jQuery = jquery;
window.$ = jquery;
import Rails from "@rails/ujs"
Rails.start();

// Disable browser scroll restoration 
if ('scrollRestoration' in history) {
  history.scrollRestoration = 'manual'
}

// Add CSS to completely disable scroll behavior
const style = document.createElement('style')
style.textContent = `
  html, body {
    scroll-behavior: auto !important;
  }
  
  /* For WebKit/iOS */
  html {
    -webkit-scroll-behavior: auto !important;
  }
`
document.head.appendChild(style)

let savedScrollPosition = null

// Save scroll position whenever we're about to leave the events page
function saveEventsScrollPosition() {
  const isEventsPage = window.location.pathname === '/events' || window.location.pathname.includes('/events?')
  if (isEventsPage) {
    savedScrollPosition = window.pageYOffset
    console.log('Saved scroll position:', savedScrollPosition) // Debug log
  }
}

// Save position when navigating away from events page
document.addEventListener('turbo:before-visit', saveEventsScrollPosition)

// Also save position when clicking links (this catches event card clicks)
document.addEventListener('click', (event) => {
  // Check if clicked element or its parent is a link
  const link = event.target.closest('a')
  if (link) {
    saveEventsScrollPosition()
  }
})

// Restore position instantly on events page load
document.addEventListener('turbo:load', () => {
  const isEventsPage = window.location.pathname === '/events' || window.location.pathname.includes('/events?')
  
  if (isEventsPage && savedScrollPosition !== null) {
    console.log('Restoring scroll position:', savedScrollPosition) // Debug log
    
    // Try multiple methods to set position instantly
    document.documentElement.scrollTop = savedScrollPosition
    document.body.scrollTop = savedScrollPosition
    
    // Also try the traditional way as backup
    window.scrollTo({
      top: savedScrollPosition,
      left: 0,
      behavior: 'auto'
    })
    
    // Don't clear savedScrollPosition here - keep it for subsequent returns
  }
  
  // Clear saved position when we navigate to a non-events page
  if (!isEventsPage) {
    savedScrollPosition = null
  }

  // Existing alert handling
  document.querySelectorAll('.alert').forEach((alert) => {
    setTimeout(() => {
      alert.classList.remove('show')
      setTimeout(() => alert.remove(), 300)
    }, 5000)
  });
});

// Simple fix for Bootstrap offcanvas backdrop cleanup
document.addEventListener('turbo:load', function() {
  // Clean up any leftover backdrops on page load
  cleanupOrphanedBackdrops();
  
  // Set up offcanvas cleanup when it's hidden
  const offcanvasElement = document.getElementById('accountMenu');
  if (offcanvasElement) {
    offcanvasElement.addEventListener('hidden.bs.offcanvas', function() {
      // Clean up after offcanvas is fully hidden
      setTimeout(cleanupOrphanedBackdrops, 100);
    });
  }
});

// Clean up before navigating to prevent backdrops from carrying over
document.addEventListener('turbo:before-visit', function() {
  cleanupOrphanedBackdrops();
});

function cleanupOrphanedBackdrops() {
  // Only clean up if no offcanvas or modal is actually open
  const hasOpenOffcanvas = document.querySelector('.offcanvas.show');
  const hasOpenModal = document.querySelector('.modal.show');
  
  if (!hasOpenOffcanvas && !hasOpenModal) {
    // Remove any orphaned backdrop elements
    document.querySelectorAll('.offcanvas-backdrop, .modal-backdrop').forEach(backdrop => {
      backdrop.remove();
    });
    
    // Clean up body classes and styles
    document.body.classList.remove('modal-open', 'offcanvas-open');
    document.body.style.overflow = '';
    document.body.style.paddingRight = '';
    
    console.log('Cleaned up orphaned backdrops');
  }
}



document.addEventListener("turbo:frame-render", (event) => {
  const frame = event.target
  if (frame.id && frame.id.startsWith("follow_button_")) {
    const btn = frame.querySelector("form button")
    if (btn) {
      btn.classList.add("btn-follow-animate")
      setTimeout(() => btn.classList.remove("btn-follow-animate"), 200)
    }
  }
})

// Add this to your application.js or create a separate native.js file

// Detect if running in native app
const isNativeApp = window.HotwireNative || navigator.userAgent.includes('Hotwire Native');

if (isNativeApp) {
  // Prevent viewport scaling that can affect navigation bars
  document.addEventListener('DOMContentLoaded', function() {
    // Create or update viewport meta tag for native app
    let viewport = document.querySelector('meta[name="viewport"]');
    if (viewport) {
      viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');
    }
    
    // REMOVED: The overscrollBehavior = 'none' lines that were disabling swipe-to-refresh
    // We want to allow overscroll for pull-to-refresh functionality
    
    // Ensure proper safe area handling
    document.documentElement.style.setProperty('--safe-area-inset-top', 'env(safe-area-inset-top)');
    document.documentElement.style.setProperty('--safe-area-inset-bottom', 'env(safe-area-inset-bottom)');
  });
  
  // Prevent Bootstrap from interfering with native scrolling
  document.addEventListener('turbo:load', function() {
    // Disable Bootstrap's scroll spy if present
    const scrollSpyElements = document.querySelectorAll('[data-bs-spy="scroll"]');
    scrollSpyElements.forEach(el => el.removeAttribute('data-bs-spy'));
    
    // Prevent modal backdrop from interfering with navigation
    document.addEventListener('show.bs.modal', function(e) {
      setTimeout(() => {
        const backdrop = document.querySelector('.modal-backdrop');
        if (backdrop) {
          backdrop.style.zIndex = '1040';
        }
      }, 100);
    });
  });
  
  // Override any scroll event listeners that might affect appearance
  let originalAddEventListener = EventTarget.prototype.addEventListener;
  EventTarget.prototype.addEventListener = function(type, listener, options) {
    if (type === 'scroll' && (this === window || this === document)) {
      // Wrap scroll listeners to prevent navigation bar appearance changes
      const wrappedListener = function(event) {
        // Prevent the event from bubbling to native scroll handlers
        event.preventDefault = function() {};
        listener.call(this, event);
      };
      return originalAddEventListener.call(this, type, wrappedListener, options);
    }
    return originalAddEventListener.call(this, type, listener, options);
  };
}

// Handle swipe-to-refresh for events page specifically
if (isNativeApp) {
  document.addEventListener('turbo:load', function() {
    // For events page, configure custom refresh behavior
    const isEventsPage = window.location.pathname === '/events' || window.location.pathname.includes('/events?')
    
    if (isEventsPage) {
      // Try multiple event names that Hotwire Native might use
      const refreshEvents = ['refresh', 'pull-to-refresh', 'hotwire:refresh', 'turbo:refresh']
      
      refreshEvents.forEach(eventName => {
        document.addEventListener(eventName, function(event) {
          console.log(`Caught refresh event: ${eventName}`) // Debug log
          
          // For events page, reload the entire page to preserve search state
          window.location.reload()
          
          // Prevent default refresh behavior
          if (event.preventDefault) {
            event.preventDefault()
          }
        })
      })
      
      // Also try window-level events
      if (window.HotwireNative) {
        // Try to override the refresh action directly
        window.addEventListener('beforeunload', function() {
          console.log('Page unloading - might be refresh')
        })
      }
    }
  })
}

// Custom modal functions for native app
function showSignInModal() {
  console.log('Showing sign in modal'); // Debug log
  const modal = document.getElementById('signinModal');
  console.log('Modal element:', modal);
  
  if (modal) {
    console.log('Modal classes before:', modal.className);
    modal.classList.remove('hiding');
    modal.classList.add('show');
    console.log('Modal classes after:', modal.className);
    console.log('Modal display style:', window.getComputedStyle(modal).display);
    document.body.style.overflow = 'hidden';
  } else {
    console.log('Sign in modal not found');
  }
}

function hideSignInModal() {
  console.log('Hiding sign in modal'); // Debug log
  const modal = document.getElementById('signinModal');
  if (modal) {
    modal.classList.add('hiding');
    document.body.style.overflow = '';
    
    setTimeout(() => {
      modal.classList.remove('show', 'hiding');
    }, 200);
  }
}

function showSignUpModal() {
  console.log('Showing sign up modal'); // Debug log
  const modal = document.getElementById('signupModal');
  console.log('Modal element:', modal);
  
  if (modal) {
    console.log('Modal classes before:', modal.className);
    modal.classList.remove('hiding');
    modal.classList.add('show');
    console.log('Modal classes after:', modal.className);
    console.log('Modal display style:', window.getComputedStyle(modal).display);
    console.log('Modal z-index:', window.getComputedStyle(modal).zIndex);
    document.body.style.overflow = 'hidden';
  } else {
    console.log('Sign up modal not found');
  }
}

function hideSignUpModal() {
  console.log('Hiding sign up modal'); // Debug log
  const modal = document.getElementById('signupModal');
  if (modal) {
    modal.classList.add('hiding');
    document.body.style.overflow = '';
    
    setTimeout(() => {
      modal.classList.remove('show', 'hiding');
    }, 200);
  }
}

// Make functions global
window.showSignInModal = showSignInModal;
window.hideSignInModal = hideSignInModal;
window.showSignUpModal = showSignUpModal;
window.hideSignUpModal = hideSignUpModal;

// Modal event listeners
document.addEventListener('turbo:load', function() {
  console.log('Setting up modal event listeners'); // Debug log
  
  // Check if CSS is loaded
  const testModal = document.getElementById('signupModal');
  if (testModal) {
    console.log('Modal CSS check - z-index:', window.getComputedStyle(testModal).zIndex);
    console.log('Modal CSS check - position:', window.getComputedStyle(testModal).position);
  }
  
  // Button click handlers
  const signInButton = document.getElementById('signInButton');
  const signUpButton = document.getElementById('signUpButton');
  
  if (signInButton) {
    console.log('Found sign in button, adding listener');
    signInButton.addEventListener('click', function(e) {
      e.preventDefault();
      console.log('Sign in button clicked');
      showSignInModal();
    });
  }
  
  if (signUpButton) {
    console.log('Found sign up button, adding listener');
    signUpButton.addEventListener('click', function(e) {
      e.preventDefault();
      console.log('Sign up button clicked');
      showSignUpModal();
    });
  }
  
  // Close modal handlers
  document.querySelectorAll('[data-close-modal]').forEach(element => {
    element.addEventListener('click', function(e) {
      e.preventDefault();
      const modalType = this.dataset.closeModal;
      console.log('Closing modal:', modalType);
      
      if (modalType === 'signin') {
        hideSignInModal();
      } else if (modalType === 'signup') {
        hideSignUpModal();
      }
    });
  });

  // Close modals with escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
      hideSignInModal();
      hideSignUpModal();
    }
  });

  // Prevent body scroll when modal is open
  document.addEventListener('touchmove', function(e) {
    if (document.querySelector('.custom-modal.show')) {
      e.preventDefault();
    }
  }, { passive: false });
});
