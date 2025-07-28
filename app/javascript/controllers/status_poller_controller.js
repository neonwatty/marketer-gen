import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.checkStatus()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // If processing is complete or failed, stop polling and refresh
        if (data.processing_status === 'completed' || data.processing_status === 'failed') {
          this.stopPolling()
          window.location.reload()
        }
      }
    } catch (error) {
      console.error('Status polling error:', error)
      // Continue polling on error
    }
  }
}