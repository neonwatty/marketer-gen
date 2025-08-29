import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="journey-compare"
export default class extends Controller {
  static targets = ["checkbox", "compareButton", "clearButton"]

  connect() {
    this.updateCompareButton()
  }

  toggle(event) {
    this.updateCompareButton()
  }

  clearAll(event) {
    event.preventDefault()
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateCompareButton()
  }

  updateCompareButton() {
    const checkedBoxes = this.checkboxTargets.filter(checkbox => checkbox.checked)
    const count = checkedBoxes.length
    
    if (count >= 2 && count <= 4) {
      this.compareButtonTarget.disabled = false
      this.compareButtonTarget.textContent = `Compare Selected (${count})`
    } else {
      this.compareButtonTarget.disabled = true
      this.compareButtonTarget.textContent = count === 0 ? 'Compare Selected' : 
                                          count === 1 ? 'Select 1 more' : 
                                          'Too many selected (max 4)'
    }
  }
}