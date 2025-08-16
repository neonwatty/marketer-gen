import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  open() {
    this.element.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }
}