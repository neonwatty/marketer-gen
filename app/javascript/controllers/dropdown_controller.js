import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
    // Close dropdown when clicking outside
    document.addEventListener('click', this.closeOnOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.closeOnOutsideClick.bind(this))
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove('hidden')
    this.element.querySelector('[aria-expanded]').setAttribute('aria-expanded', 'true')
    this.isOpen = true
  }

  close() {
    this.menuTarget.classList.add('hidden')
    this.element.querySelector('[aria-expanded]').setAttribute('aria-expanded', 'false')
    this.isOpen = false
  }

  closeOnOutsideClick(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }
}