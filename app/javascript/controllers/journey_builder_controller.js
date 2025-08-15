import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stepsContainer", "step"]
  static values = { journeyId: Number }

  connect() {
    this.initializeSortable()
  }

  initializeSortable() {
    if (this.hasStepsContainerTarget) {
      // Add drag and drop functionality
      this.stepsContainerTarget.addEventListener('dragover', this.handleDragOver.bind(this))
      this.stepsContainerTarget.addEventListener('drop', this.handleDrop.bind(this))
      
      // Make steps draggable
      this.stepTargets.forEach((step, index) => {
        this.makeStepDraggable(step, index)
      })
    }
  }

  makeStepDraggable(step, index) {
    step.draggable = true
    step.dataset.stepIndex = index
    
    step.addEventListener('dragstart', (e) => {
      e.dataTransfer.setData('text/plain', index)
      step.classList.add('opacity-50')
    })
    
    step.addEventListener('dragend', (e) => {
      step.classList.remove('opacity-50')
    })
  }

  handleDragOver(e) {
    e.preventDefault()
    const draggingElement = document.querySelector('.opacity-50')
    const closestStep = this.getClosestStep(e.clientY)
    
    if (closestStep && draggingElement !== closestStep) {
      const rect = closestStep.getBoundingClientRect()
      const offset = e.clientY - rect.top
      
      if (offset < rect.height / 2) {
        this.stepsContainerTarget.insertBefore(draggingElement, closestStep)
      } else {
        this.stepsContainerTarget.insertBefore(draggingElement, closestStep.nextSibling)
      }
    }
  }

  handleDrop(e) {
    e.preventDefault()
    this.updateStepOrder()
  }

  getClosestStep(y) {
    const draggableElements = [...this.stepTargets.filter(step => !step.classList.contains('opacity-50'))]
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  updateStepOrder() {
    const stepIds = this.stepTargets.map(step => step.dataset.stepId)
    
    // Send AJAX request to update order
    fetch(`/journeys/${this.journeyIdValue}/reorder_steps`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ step_ids: stepIds })
    })
    .then(response => {
      if (response.ok) {
        // Update sequence numbers in UI
        this.stepTargets.forEach((step, index) => {
          const numberElement = step.querySelector('.step-number')
          if (numberElement) {
            numberElement.textContent = index + 1
          }
        })
      }
    })
    .catch(error => {
      console.error('Error updating step order:', error)
      // Reload page on error to reset state
      window.location.reload()
    })
  }
}