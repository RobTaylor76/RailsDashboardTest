import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "refreshBtn"]
  static values = { 
    refreshInterval: { type: Number, default: 30000 }, // 30 seconds
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("🚀 Dashboard controller connected")
    console.log("📊 Auto-refresh enabled:", this.autoRefreshValue)
    console.log("⏱️ Refresh interval:", this.refreshIntervalValue)
    
    this.startAutoRefresh()
    this.setupRefreshButton()
    
    // Add a visual indicator that the controller is connected
    this.showConnectedIndicator()
  }

  disconnect() {
    console.log("🔌 Dashboard controller disconnected")
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    if (this.autoRefreshValue) {
      console.log("🔄 Starting auto-refresh timer")
      this.refreshTimer = setInterval(() => {
        console.log("⏰ Auto-refresh triggered at", new Date().toLocaleTimeString())
        this.refresh()
      }, this.refreshIntervalValue)
    }
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      console.log("⏹️ Stopping auto-refresh timer")
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  refresh() {
    console.log("🔄 Refreshing dashboard data...")
    
    // Show loading state
    this.showLoadingState()
    
    // Try Turbo Stream first, then fallback to JSON
    this.tryTurboStreamRefresh()
  }

  tryTurboStreamRefresh() {
    // Make Turbo Stream request
    fetch("/dashboard/refresh", {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      console.log("📡 Turbo Stream response status:", response.status)
      if (response.ok) {
        return response.text()
      }
      throw new Error("Turbo Stream failed")
    })
    .then(html => {
      console.log("✅ Turbo Stream successful, processing response")
      const success = this.processTurboStreamResponse(html)
      if (success) {
        this.hideLoadingState()
        this.updateLastRefreshTime()
        this.showSuccessIndicator()
      } else {
        console.log("⚠️ Turbo Stream processing failed, trying JSON fallback")
        this.tryJsonRefresh()
      }
    })
    .catch(error => {
      console.error("❌ Turbo Stream error:", error)
      console.log("🔄 Trying JSON fallback")
      this.tryJsonRefresh()
    })
  }

  tryJsonRefresh() {
    // Make JSON request as fallback
    fetch("/dashboard/refresh", {
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      console.log("📡 JSON response status:", response.status)
      if (response.ok) {
        return response.json()
      }
      throw new Error("JSON refresh failed")
    })
    .then(data => {
      console.log("✅ JSON refresh successful, updating DOM")
      this.updateDomWithJsonData(data)
      this.hideLoadingState()
      this.updateLastRefreshTime()
      this.showSuccessIndicator()
    })
    .catch(error => {
      console.error("❌ JSON refresh error:", error)
      this.hideLoadingState()
      this.showError("Failed to refresh dashboard")
    })
  }

  processTurboStreamResponse(html) {
    console.log("🔄 Processing Turbo Stream response")
    
    try {
      // Parse the Turbo Stream response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const turboStream = doc.querySelector('turbo-stream')
      
      if (turboStream) {
        const action = turboStream.getAttribute('action')
        const target = turboStream.getAttribute('target')
        const template = turboStream.querySelector('template')
        
        console.log("📋 Turbo Stream - Action:", action, "Target:", target)
        
        if (template && target) {
          const targetElement = document.getElementById(target)
          if (targetElement) {
            if (action === 'update') {
              targetElement.innerHTML = template.innerHTML
              console.log("✅ DOM updated successfully with Turbo Stream")
              return true
            } else if (action === 'replace') {
              targetElement.outerHTML = template.innerHTML
              console.log("✅ DOM replaced successfully with Turbo Stream")
              return true
            }
          } else {
            console.warn("⚠️ Target element not found:", target)
          }
        }
      } else {
        console.warn("⚠️ No turbo-stream element found in response")
      }
    } catch (error) {
      console.error("❌ Error processing Turbo Stream:", error)
    }
    
    return false
  }

  updateDomWithJsonData(data) {
    console.log("🔄 Updating DOM with JSON data")
    
    try {
      // Update system status
      const uptimeElement = document.getElementById('uptime')
      const lastUpdatedElement = document.getElementById('last-updated')
      const statusElement = document.querySelector('.status-indicator')
      
      if (uptimeElement) uptimeElement.textContent = data.system_status.uptime
      if (lastUpdatedElement) lastUpdatedElement.textContent = data.system_status.last_check
      if (statusElement) {
        statusElement.textContent = data.system_status.status
        statusElement.className = `status-indicator ${data.system_status.status}`
      }
      
      // Update metrics
      const cpuElement = document.getElementById('cpu-usage')
      const memoryElement = document.getElementById('memory-usage')
      const diskElement = document.getElementById('disk-usage')
      const networkElement = document.getElementById('network-usage')
      const responseElement = document.getElementById('response-time')
      
      if (cpuElement) cpuElement.textContent = data.metrics.cpu
      if (memoryElement) memoryElement.textContent = data.metrics.memory
      if (diskElement) diskElement.textContent = data.metrics.disk
      if (networkElement) networkElement.textContent = data.metrics.network
      if (responseElement) responseElement.textContent = data.metrics.response_time
      
      // Update activity feed
      const activityFeed = document.getElementById('activity-feed')
      if (activityFeed && data.activities) {
        activityFeed.innerHTML = data.activities.map(activity => `
          <div class="activity-item ${activity.css_class}">
            <span class="activity-time">${activity.time}</span>
            <span class="activity-text">${activity.message}</span>
          </div>
        `).join('')
      }
      
      console.log("✅ DOM updated successfully with JSON data")
    } catch (error) {
      console.error("❌ Error updating DOM with JSON data:", error)
    }
  }

  setupRefreshButton() {
    if (this.hasRefreshBtnTarget) {
      console.log("🔘 Setting up refresh button")
      this.refreshBtnTarget.addEventListener("click", (e) => {
        e.preventDefault()
        console.log("🖱️ Manual refresh button clicked")
        this.refresh()
      })
    } else {
      console.log("⚠️ Refresh button target not found")
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

  showConnectedIndicator() {
    // Add a visual indicator that the controller is connected
    const indicator = document.getElementById("auto-refresh-status")
    if (indicator) {
      indicator.style.backgroundColor = "#10b981"
      indicator.querySelector(".status-text").textContent = "Auto-refresh connected"
    }
  }

  showSuccessIndicator() {
    // Briefly show success indicator
    const indicator = document.getElementById("auto-refresh-status")
    if (indicator) {
      const originalText = indicator.querySelector(".status-text").textContent
      indicator.style.backgroundColor = "#059669"
      indicator.querySelector(".status-text").textContent = "Updated successfully"
      
      setTimeout(() => {
        indicator.style.backgroundColor = "#10b981"
        indicator.querySelector(".status-text").textContent = originalText
      }, 2000)
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