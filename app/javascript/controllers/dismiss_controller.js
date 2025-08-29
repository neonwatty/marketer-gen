import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dismiss"
export default class extends Controller {
  dismiss(event) {
    event.preventDefault()
    this.element.remove()
  }
}