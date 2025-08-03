import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }
  
  connect() {
    this.sortable = Sortable.create(this.listTarget, {
      animation: 150,
      ghostClass: "opacity-50",
      handle: ".cursor-move",
      onEnd: this.updateOrder.bind(this)
    })
  }
  
  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }
  
  async updateOrder(_event) {
    const items = Array.from(this.listTarget.children).map((item, index) => ({
      id: item.dataset.id,
      position: index
    }))
    
    if (this.hasUrlValue) {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ items })
      })
      
      if (!response.ok) {
        console.error('Failed to update order')
        // Optionally revert the order
      }
    }
  }
}