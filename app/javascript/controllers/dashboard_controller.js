import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "refreshBtn"]
  static values = { 
    refreshInterval: { type: Number, default: 30000 }, // 30 seconds
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("Dashboard controller connected")
    this.startAutoRefresh()
    this.setupRefreshButton()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    if (this.autoRefreshValue) {
      this.refreshTimer = setInterval(() => {
        this.refresh()
      }, this.refreshIntervalValue)
    }
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  refresh() {
    console.log("Refreshing dashboard data...")
    
    // Show loading state
    this.showLoadingState()
    
    // Make Turbo Stream request
    fetch("/dashboard/refresh", {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      if (response.ok) {
        return response.text()
      }
      throw new Error("Refresh failed")
    })
    .then(html => {
      // Turbo will handle the stream update automatically
      this.hideLoadingState()
      this.updateLastRefreshTime()
    })
    .catch(error => {
      console.error("Dashboard refresh error:", error)
      this.hideLoadingState()
      this.showError("Failed to refresh dashboard")
    })
  }

  setupRefreshButton() {
    if (this.hasRefreshBtnTarget) {
      this.refreshBtnTarget.addEventListener("click", (e) => {
        e.preventDefault()
        this.refresh()
      })
    }
  }

  showLoadingState() {
    // Add loading indicator to refresh button
    if (this.hasRefreshBtnTarget) {
      this.refreshBtnTarget.textContent = "Refreshing..."
      this.refreshBtnTarget.disabled = true
    }
  }

  hideLoadingState() {
    // Restore refresh button
    if (this.hasRefreshBtnTarget) {
      this.refreshBtnTarget.textContent = "Refresh Data"
      this.refreshBtnTarget.disabled = false
    }
  }

  updateLastRefreshTime() {
    const now = new Date()
    const timeString = now.toLocaleTimeString()
    
    // Update the last refresh time in the footer
    const footerInfo = document.querySelector(".dashboard-footer-info p:last-child")
    if (footerInfo) {
      footerInfo.textContent = `Last data refresh: ${timeString}`
    }
  }

  showError(message) {
    // Simple error notification
    const errorDiv = document.createElement("div")
    errorDiv.className = "error-notification"
    errorDiv.textContent = message
    errorDiv.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #ef4444;
      color: white;
      padding: 1rem;
      border-radius: 8px;
      z-index: 1000;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    `
    
    document.body.appendChild(errorDiv)
    
    // Remove after 5 seconds
    setTimeout(() => {
      if (errorDiv.parentNode) {
        errorDiv.parentNode.removeChild(errorDiv)
      }
    }, 5000)
  }

  // Toggle auto-refresh
  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    } else {
      this.stopAutoRefresh()
    }
  }
} 