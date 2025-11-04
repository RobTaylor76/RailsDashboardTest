import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true  // Enable debug mode to see controller registration
window.Stimulus   = application

// Log when controllers are registered
application.logLevel = application.logLevel || 1  // Enable logging

export { application }
