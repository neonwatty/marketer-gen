import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "status", "counter"]
  static values = { clicks: Number }

  connect() {
    console.log("Campaign controller connected!")
    this.clicksValue = 0
    this.updateCounter()
  }

  increment() {
    this.clicksValue++
    this.updateCounter()
    
    // Simulate campaign status change
    if (this.clicksValue >= 5) {
      this.statusTarget.textContent = "Active Campaign 🚀"
      this.statusTarget.className = "px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium"
    }
  }

  updateCounter() {
    this.counterTarget.textContent = this.clicksValue
  }

  // Demonstrate campaign name change
  updateTitle(event) {
    this.titleTarget.textContent = event.target.value || "Marketing Campaign"
  }
}