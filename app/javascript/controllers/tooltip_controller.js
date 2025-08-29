import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
export default class extends Controller {
  static targets = ["content"]

  show() {
    this.contentTarget.classList.remove('invisible', 'opacity-0')
    this.contentTarget.classList.add('visible', 'opacity-100')
  }

  hide() {
    this.contentTarget.classList.remove('visible', 'opacity-100')
    this.contentTarget.classList.add('invisible', 'opacity-0')
  }
}