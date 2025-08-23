import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["content", "refreshBtn"]
  static values = { 
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    console.log("🚀 WebSocket Dashboard controller connected")
    console.log("📊 Auto-refresh enabled:", this.autoRefreshValue)
    console.log("🔌 Action Cable consumer:", consumer)
    
    this.setupRefreshButton()
    this.showConnectedIndicator()
    
    if (this.autoRefreshValue) {
      this.startWebSocketConnection()
    }
  }

  disconnect() {
    console.log("🔌 WebSocket Dashboard controller disconnected")
    this.stopWebSocketConnection()
  }

  startWebSocketConnection() {
    console.log("🔄 Starting WebSocket connection")
    
    try {
      // Subscribe to the dashboard updates channel
      this.subscription = consumer.subscriptions.create("DashboardUpdatesChannel", {
        connected: () => {
          console.log("✅ WebSocket connection opened")
          this.showConnectedIndicator()
        },
        
        disconnected: () => {
          console.log("❌ WebSocket connection closed")
          this.showError("WebSocket connection lost")
        },
        
        rejected: () => {
          console.log("❌ WebSocket connection rejected")
          this.showError("WebSocket connection rejected")
        },
        
        received: (data) => {
          console.log("📡 WebSocket message received:", data)
          this.handleWebSocketMessage(data)
        }
      })
      
      console.log("🔌 WebSocket subscription created:", this.subscription)
      
    } catch (error) {
      console.error("❌ Error creating WebSocket connection:", error)
      this.showError("Failed to establish WebSocket connection")
    }
  }

  stopWebSocketConnection() {
    if (this.subscription) {
      console.log("⏹️ Stopping WebSocket connection")
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  handleWebSocketMessage(data) {
    try {
      console.log("✅ Processing WebSocket data:", data.timestamp)
      
      this.updateDashboardWithData(data)
      this.updateLastRefreshTime()
      this.showSuccessIndicator()
      
    } catch (error) {
      console.error("❌ Error processing WebSocket data:", error)
    }
  }

  updateDashboardWithData(data) {
    console.log("🔄 Updating dashboard with WebSocket data")
    
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
      
      console.log("✅ Dashboard updated successfully with WebSocket data")
    } catch (error) {
      console.error("❌ Error updating dashboard with WebSocket data:", error)
    }
  }

  setupRefreshButton() {
    if (this.hasRefreshBtnTarget) {
      console.log("🔘 Setting up refresh button")
      this.refreshBtnTarget.addEventListener("click", (e) => {
        e.preventDefault()
        console.log("🖱️ Manual refresh button clicked")
        this.manualRefresh()
      })
    } else {
      console.log("⚠️ Refresh button target not found")
    }
  }

  manualRefresh() {
    // For manual refresh, we can still use the JSON endpoint
    console.log("🔄 Manual refresh triggered")
    
    this.showLoadingState()
    
    fetch("/dashboard/refresh", {
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      if (response.ok) {
        return response.json()
      }
      throw new Error("Manual refresh failed")
    })
    .then(data => {
      console.log("✅ Manual refresh successful")
      this.updateDashboardWithData(data)
      this.hideLoadingState()
      this.updateLastRefreshTime()
      this.showSuccessIndicator()
    })
    .catch(error => {
      console.error("❌ Manual refresh error:", error)
      this.hideLoadingState()
      this.showError("Manual refresh failed")
    })
  }

  showLoadingState() {
    if (this.hasRefreshBtnTarget) {
      this.refreshBtnTarget.textContent = "Refreshing..."
      this.refreshBtnTarget.disabled = true
    }
  }

  hideLoadingState() {
    if (this.hasRefreshBtnTarget) {
      this.refreshBtnTarget.textContent = "Refresh Data"
      this.refreshBtnTarget.disabled = false
    }
  }

  updateLastRefreshTime() {
    const now = new Date()
    const timeString = now.toLocaleTimeString()
    
    const footerInfo = document.querySelector(".dashboard-footer-info p:last-child")
    if (footerInfo) {
      footerInfo.textContent = `Last data refresh: ${timeString}`
    }
  }

  showConnectedIndicator() {
    const indicator = document.getElementById("auto-refresh-status")
    if (indicator) {
      indicator.style.backgroundColor = "#10b981"
      indicator.querySelector(".status-text").textContent = "WebSocket connected"
    }
  }

  showSuccessIndicator() {
    const indicator = document.getElementById("auto-refresh-status")
    if (indicator) {
      const originalText = indicator.querySelector(".status-text").textContent
      indicator.style.backgroundColor = "#059669"
      indicator.querySelector(".status-text").textContent = "Updated via WebSocket"
      
      setTimeout(() => {
        indicator.style.backgroundColor = "#10b981"
        indicator.querySelector(".status-text").textContent = originalText
      }, 2000)
    }
  }

  showError(message) {
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
    
    setTimeout(() => {
      if (errorDiv.parentNode) {
        errorDiv.parentNode.removeChild(errorDiv)
      }
    }, 5000)
  }

  // Toggle WebSocket connection
  toggleWebSocket() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.startWebSocketConnection()
    } else {
      this.stopWebSocketConnection()
    }
  }
} 