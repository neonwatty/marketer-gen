import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "dropIndicator"]
  static values = { timelineData: Object }

  connect() {
    console.log("Timeline drag-drop controller connected")
    this.setupDragAndDrop()
    this.bindKeyboardShortcuts()
  }

  setupDragAndDrop() {
    this.draggedElement = null
    this.dragStartIndex = null
    
    // Make phase elements draggable
    this.containerTarget.addEventListener('dragstart', this.dragStart.bind(this))
    this.containerTarget.addEventListener('dragend', this.dragEnd.bind(this))
    this.containerTarget.addEventListener('dragover', this.dragOver.bind(this))
    this.containerTarget.addEventListener('drop', this.drop.bind(this))
    this.containerTarget.addEventListener('dragenter', this.dragEnter.bind(this))
    this.containerTarget.addEventListener('dragleave', this.dragLeave.bind(this))
  }

  bindKeyboardShortcuts() {
    document.addEventListener('keydown', (event) => {
      // Only handle shortcuts when dashboard is focused
      if (!this.element.contains(document.activeElement)) {return}
      
      switch(event.key) {
        case 'a':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            this.addPhase()
          }
          break
        case 'z':
          if (event.ctrlKey || event.metaKey) {
            event.preventDefault()
            this.undoLastAction()
          }
          break
        case 'Escape':
          this.clearSelection()
          break
      }
    })
  }

  dragStart(event) {
    const phase = event.target.closest('.timeline-phase')
    if (!phase) {return}
    
    this.draggedElement = phase
    this.dragStartIndex = Array.from(phase.parentNode.children).indexOf(phase)
    
    phase.classList.add('opacity-50', 'scale-95')
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', phase.outerHTML)
    
    // Store phase data for potential API updates
    this.draggedPhaseData = {
      id: phase.dataset.phaseId,
      index: this.dragStartIndex
    }
  }

  dragEnd(event) {
    const phase = event.target.closest('.timeline-phase')
    if (phase) {
      phase.classList.remove('opacity-50', 'scale-95')
    }
    
    this.hideDropIndicator()
    this.draggedElement = null
    this.dragStartIndex = null
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    
    const afterElement = this.getDragAfterElement(event.clientY)
    const dropIndicator = this.dropIndicatorTarget
    
    if (afterElement == null) {
      this.containerTarget.appendChild(dropIndicator)
    } else {
      this.containerTarget.insertBefore(dropIndicator, afterElement)
    }
    
    this.showDropIndicator()
  }

  dragEnter(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    // Only hide indicator if leaving the container entirely
    if (!this.containerTarget.contains(event.relatedTarget)) {
      this.hideDropIndicator()
    }
  }

  drop(event) {
    event.preventDefault()
    
    if (!this.draggedElement) {return}
    
    const afterElement = this.getDragAfterElement(event.clientY)
    const newIndex = afterElement ? 
      Array.from(this.containerTarget.children).indexOf(afterElement) :
      this.containerTarget.children.length
    
    // Only proceed if position actually changed
    if (newIndex !== this.dragStartIndex && newIndex !== this.dragStartIndex + 1) {
      this.movePhase(this.draggedElement, afterElement, newIndex)
      this.savePhaseOrder()
    }
    
    this.hideDropIndicator()
  }

  getDragAfterElement(y) {
    const draggableElements = [...this.containerTarget.querySelectorAll('.timeline-phase:not(.opacity-50)')]
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      
      if (offset < 0 && offset > closest.offset) {
        return { offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  movePhase(phase, afterElement, newIndex) {
    if (afterElement == null) {
      this.containerTarget.appendChild(phase)
    } else {
      this.containerTarget.insertBefore(phase, afterElement)
    }
    
    // Update visual indicators
    this.updatePhaseNumbers()
    this.recalculateTimeline()
    
    // Add visual feedback
    phase.classList.add('bg-blue-50', 'border-blue-300')
    setTimeout(() => {
      phase.classList.remove('bg-blue-50', 'border-blue-300')
    }, 1000)
  }

  updatePhaseNumbers() {
    const phases = this.containerTarget.querySelectorAll('.timeline-phase')
    phases.forEach((phase, index) => {
      const phaseHeader = phase.querySelector('h5')
      if (phaseHeader) {
        phaseHeader.textContent = phaseHeader.textContent.replace(/Phase \d+:/, `Phase ${index + 1}:`)
      }
      phase.dataset.phaseIndex = index
    })
  }

  recalculateTimeline() {
    // Recalculate start weeks for each phase
    let cumulativeWeeks = 0
    const phases = this.containerTarget.querySelectorAll('.timeline-phase')
    
    phases.forEach(phase => {
      const durationWeeks = parseInt(phase.dataset.duration) || 4
      const timelineBar = phase.querySelector('.h-3 > div')
      const weekMarkers = phase.querySelector('.absolute.-bottom-5')
      
      if (timelineBar && weekMarkers) {
        // Update timeline bar position
        const totalWeeks = this.calculateTotalWeeks()
        const barWidth = (durationWeeks / totalWeeks) * 100
        const barLeft = (cumulativeWeeks / totalWeeks) * 100
        
        timelineBar.style.width = `${barWidth}%`
        timelineBar.style.marginLeft = `${barLeft}%`
        
        // Update week markers
        weekMarkers.innerHTML = `
          <span>Week ${cumulativeWeeks}</span>
          <span>Week ${cumulativeWeeks + durationWeeks}</span>
        `
      }
      
      cumulativeWeeks += durationWeeks
    })
  }

  calculateTotalWeeks() {
    const phases = this.containerTarget.querySelectorAll('.timeline-phase')
    return Array.from(phases).reduce((total, phase) => {
      return total + (parseInt(phase.dataset.duration) || 4)
    }, 0)
  }

  savePhaseOrder() {
    const phases = Array.from(this.containerTarget.querySelectorAll('.timeline-phase'))
    const phaseOrder = phases.map((phase, index) => ({
      id: phase.dataset.phaseId,
      position: index,
      start_week: this.calculateStartWeek(index)
    }))
    
    fetch(`${window.location.pathname  }/reorder_phases`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ phases: phaseOrder })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showSuccessMessage('Timeline updated successfully')
      } else {
        this.showErrorMessage('Failed to save timeline changes')
      }
    })
    .catch(error => {
      console.error('Error saving phase order:', error)
      this.showErrorMessage('An error occurred while saving changes')
    })
  }

  calculateStartWeek(phaseIndex) {
    let startWeek = 0
    const phases = this.containerTarget.querySelectorAll('.timeline-phase')
    
    for (let i = 0; i < phaseIndex; i++) {
      startWeek += parseInt(phases[i].dataset.duration) || 4
    }
    
    return startWeek
  }

  showDropIndicator() {
    this.dropIndicatorTarget.classList.remove('hidden')
    this.dropIndicatorTarget.classList.add('block')
  }

  hideDropIndicator() {
    this.dropIndicatorTarget.classList.add('hidden')
    this.dropIndicatorTarget.classList.remove('block')
  }

  addPhase() {
    // Show add phase modal or inline form
    const newPhaseForm = this.createPhaseForm()
    this.containerTarget.appendChild(newPhaseForm)
    newPhaseForm.querySelector('input[name="phase_name"]').focus()
  }

  createPhaseForm() {
    const form = document.createElement('div')
    form.className = 'timeline-phase bg-white border-2 border-dashed border-blue-300 rounded-lg p-4 mb-4'
    form.innerHTML = `
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Phase Name</label>
          <input type="text" name="phase_name" 
                 class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                 placeholder="Enter phase name">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Duration (weeks)</label>
          <input type="number" name="duration_weeks" value="4" min="1" max="52"
                 class="block w-20 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
        </div>
        <div class="flex gap-2">
          <button type="button" onclick="this.closest('.timeline-phase').remove()"
                  class="px-3 py-1 text-sm text-gray-600 bg-gray-100 rounded hover:bg-gray-200 transition-colors">
            Cancel
          </button>
          <button type="button" onclick="this.saveNewPhase(this)"
                  class="px-3 py-1 text-sm text-white bg-blue-600 rounded hover:bg-blue-700 transition-colors">
            Add Phase
          </button>
        </div>
      </div>
    `
    return form
  }

  editPhase(event) {
    const phaseId = event.target.dataset.phaseId
    const phase = this.containerTarget.querySelector(`[data-phase-id="${phaseId}"]`)
    
    if (phase) {
      this.showPhaseEditModal(phase)
    }
  }

  showPhaseEditModal(phase) {
    // Create and show phase edit modal
    const modal = this.createPhaseEditModal(phase)
    document.body.appendChild(modal)
  }

  createPhaseEditModal(phase) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50'
    modal.innerHTML = `
      <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
        <div class="mt-3">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Edit Phase</h3>
          <form class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Phase Name</label>
              <input type="text" name="phase_name" value="${phase.querySelector('h5').textContent.split(':')[1].trim()}"
                     class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Duration (weeks)</label>
              <input type="number" name="duration_weeks" value="${phase.dataset.duration || 4}" min="1" max="52"
                     class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
            </div>
            <div class="flex justify-end gap-3 pt-4">
              <button type="button" onclick="this.closest('.fixed').remove()"
                      class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button type="submit"
                      class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 transition-colors">
                Save Changes
              </button>
            </div>
          </form>
        </div>
      </div>
    `
    
    // Handle form submission
    modal.querySelector('form').addEventListener('submit', (event) => {
      event.preventDefault()
      this.savePhaseEdit(phase, event.target)
      modal.remove()
    })
    
    return modal
  }

  savePhaseEdit(phase, form) {
    const formData = new FormData(form)
    const phaseData = {
      name: formData.get('phase_name'),
      duration_weeks: parseInt(formData.get('duration_weeks'))
    }
    
    // Update phase in UI
    const phaseHeader = phase.querySelector('h5')
    const phaseIndex = Array.from(phase.parentNode.children).indexOf(phase) + 1
    phaseHeader.textContent = `Phase ${phaseIndex}: ${phaseData.name}`
    phase.dataset.duration = phaseData.duration_weeks
    
    // Update duration display
    const durationSpan = phase.querySelector('svg + span')
    if (durationSpan) {
      durationSpan.textContent = `${phaseData.duration_weeks} weeks`
    }
    
    // Recalculate timeline
    this.recalculateTimeline()
    
    // Save to server
    this.savePhaseOrder()
  }

  zoomIn() {
    this.adjustTimelineZoom(1.25)
  }

  zoomOut() {
    this.adjustTimelineZoom(0.8)
  }

  adjustTimelineZoom(factor) {
    const container = this.containerTarget
    const currentScale = parseFloat(container.dataset.scale || '1')
    const newScale = Math.max(0.5, Math.min(2, currentScale * factor))
    
    container.dataset.scale = newScale
    container.style.transform = `scale(${newScale})`
    container.style.transformOrigin = 'top left'
    
    // Adjust container size to prevent overflow
    container.style.width = `${100 / newScale}%`
  }

  clearSelection() {
    const selectedPhases = this.containerTarget.querySelectorAll('.timeline-phase.selected')
    selectedPhases.forEach(phase => {
      phase.classList.remove('selected', 'ring-2', 'ring-blue-500')
    })
  }

  undoLastAction() {
    // Implement undo functionality for the last drag operation
    console.log('Undo functionality would be implemented here')
  }

  showSuccessMessage(message) {
    this.showMessage(message, 'bg-green-100 border-green-400 text-green-700')
  }

  showErrorMessage(message) {
    this.showMessage(message, 'bg-red-100 border-red-400 text-red-700')
  }

  showMessage(message, classes) {
    const notification = document.createElement('div')
    notification.className = `fixed bottom-4 right-4 ${classes} px-4 py-2 rounded border shadow-lg z-50`
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}