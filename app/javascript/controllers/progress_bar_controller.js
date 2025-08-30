import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="progress-bar"
export default class extends Controller {
  connect() {
    // Find all elements with progress width data attributes and set their width
    const progressElements = this.element.querySelectorAll('[data-progress-width]')
    progressElements.forEach(element => {
      const width = element.dataset.progressWidth
      if (width !== undefined) {
        element.style.width = `${width}%`
      }
    })
    
    // Find all elements with progress height data attributes and set their height
    const progressHeightElements = this.element.querySelectorAll('[data-progress-height]')
    progressHeightElements.forEach(element => {
      const height = element.dataset.progressHeight
      if (height !== undefined) {
        element.style.height = `${height}%`
      }
    })
  }
}