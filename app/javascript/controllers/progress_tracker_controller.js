import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="progress-tracker"
export default class extends Controller {
  static targets = ["progressBar", "percentage", "status", "step", "message"]
  static values = { 
    taskId: String,
    refreshInterval: { type: Number, default: 2000 },
    autoRefresh: { type: Boolean, default: true },
    endpoint: String
  }

  connect() {
    console.log("Progress tracker connected for task:", this.taskIdValue)
    this.intervalId = null
    
    if (this.autoRefreshValue && this.taskIdValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    if (this.intervalId) return // Already polling
    
    this.intervalId = setInterval(() => {
      this.checkProgress()
    }, this.refreshIntervalValue)
    
    // Initial check
    this.checkProgress()
  }

  stopPolling() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }
  }

  async checkProgress() {
    if (!this.taskIdValue || !this.endpointValue) return

    try {
      const response = await fetch(`${this.endpointValue}?task_id=${this.taskIdValue}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.updateProgress(data)

      // Stop polling if task is completed or failed
      if (data.status === 'completed' || data.status === 'failed') {
        this.stopPolling()
        
        // Emit completion event
        this.dispatch('taskCompleted', { 
          detail: { 
            taskId: this.taskIdValue, 
            status: data.status,
            data: data
          }
        })
      }

    } catch (error) {
      console.error('Progress check failed:', error)
      // Don't stop polling on network errors, just log them
    }
  }

  updateProgress(data) {
    const { 
      percentage = 0, 
      status = 'pending', 
      current_step = 0, 
      message = '', 
      steps = [],
      estimated_time_remaining = null 
    } = data

    // Update progress bar
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
      this.progressBarTarget.className = this.progressBarTarget.className.replace(
        /bg-(gray|blue|green|red|yellow)-\d+/g, 
        `bg-${this.getProgressColor(status)}-600`
      )
    }

    // Update percentage display
    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${percentage}%`
    }

    // Update status
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = status.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())
      this.statusTarget.className = this.statusTarget.className.replace(
        /text-(gray|blue|green|red|yellow)-\d+/g,
        `text-${this.getProgressColor(status)}-800`
      )
      this.statusTarget.className = this.statusTarget.className.replace(
        /bg-(gray|blue|green|red|yellow)-\d+/g,
        `bg-${this.getProgressColor(status)}-100`
      )
    }

    // Update step indicators
    if (this.hasStepTarget) {
      this.stepTargets.forEach((stepElement, index) => {
        const stepCompleted = index < current_step
        const stepCurrent = index === current_step
        const stepError = stepCurrent && status === 'failed'
        
        // Update step circle
        const circle = stepElement.querySelector('.step-circle')
        if (circle) {
          circle.className = circle.className.replace(/bg-\w+-\d+/g, '')
          circle.className = circle.className.replace(/border-\w+-\d+/g, '')
          circle.className = circle.className.replace(/text-\w+-\d+/g, '')
          
          if (stepCompleted) {
            circle.classList.add('bg-green-600', 'border-green-600', 'text-white')
            circle.innerHTML = this.getCheckIcon()
          } else if (stepError) {
            circle.classList.add('bg-red-600', 'border-red-600', 'text-white')
            circle.innerHTML = this.getErrorIcon()
          } else if (stepCurrent) {
            circle.classList.add('bg-blue-600', 'border-blue-600', 'text-white')
            circle.innerHTML = this.getLoadingIcon()
          } else {
            circle.classList.add('bg-white', 'border-gray-300', 'text-gray-500')
            circle.innerHTML = index + 1
          }
        }

        // Update step label color
        const label = stepElement.querySelector('.step-label')
        if (label) {
          label.className = label.className.replace(/text-\w+-\d+/g, '')
          if (stepCompleted) {
            label.classList.add('text-green-600')
          } else if (stepError) {
            label.classList.add('text-red-600')
          } else if (stepCurrent) {
            label.classList.add('text-blue-600')
          } else {
            label.classList.add('text-gray-500')
          }
        }
      })
    }

    // Update message
    if (this.hasMessageTarget && message) {
      this.messageTarget.textContent = message
      
      // Add estimated time if available
      if (estimated_time_remaining && status === 'generating') {
        this.messageTarget.textContent += ` (Est. ${estimated_time_remaining} remaining)`
      }
    }

    // Update page title for background tab awareness
    if (status === 'generating') {
      document.title = `(${percentage}%) Generating...`
    } else if (status === 'completed') {
      document.title = '✓ Generation Complete'
    } else if (status === 'failed') {
      document.title = '✗ Generation Failed'
    }
  }

  getProgressColor(status) {
    switch (status) {
      case 'completed': return 'green'
      case 'failed': return 'red'
      case 'generating': return 'blue'
      case 'pending': return 'gray'
      default: return 'gray'
    }
  }

  getCheckIcon() {
    return `<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
    </svg>`
  }

  getErrorIcon() {
    return `<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
    </svg>`
  }

  getLoadingIcon() {
    return `<div class="w-2 h-2 bg-current rounded-full animate-pulse"></div>`
  }

  // Manual refresh method
  refresh() {
    this.checkProgress()
  }

  // Method to update refresh interval
  updateInterval(newInterval) {
    this.refreshIntervalValue = newInterval
    if (this.intervalId) {
      this.stopPolling()
      this.startPolling()
    }
  }
}