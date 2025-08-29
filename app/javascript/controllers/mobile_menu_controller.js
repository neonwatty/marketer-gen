import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.preventDefault()
    
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove('hidden')
    this.element.setAttribute('aria-expanded', 'true')
    this.isOpen = true
  }

  close() {
    this.menuTarget.classList.add('hidden')
    this.element.setAttribute('aria-expanded', 'false')
    this.isOpen = false
  }
}