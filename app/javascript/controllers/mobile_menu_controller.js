import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay"]
  static classes = ["open"]

  connect() {
    // Bind click outside handler to the controller instance
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle() {
    const isOpen = this.menuTarget.classList.contains("translate-x-0")
    
    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    // Show overlay
    this.overlayTarget.classList.remove("hidden")
    this.overlayTarget.classList.add("opacity-50")
    
    // Slide menu in from right
    this.menuTarget.classList.remove("translate-x-full")
    this.menuTarget.classList.add("translate-x-0")
    
    // Add click outside listener
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 100)
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Set ARIA attributes
    this.menuTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    // Hide overlay
    this.overlayTarget.classList.remove("opacity-50")
    this.overlayTarget.classList.add("hidden")
    
    // Slide menu out to right
    this.menuTarget.classList.remove("translate-x-0")
    this.menuTarget.classList.add("translate-x-full")
    
    // Remove click outside listener
    document.removeEventListener("click", this.clickOutsideHandler)
    
    // Restore body scroll
    document.body.style.overflow = ""
    
    // Set ARIA attributes
    this.menuTarget.setAttribute("aria-expanded", "false")
  }

  clickOutside(event) {
    // Don't close if clicking on the menu itself or the hamburger button
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  // Handle escape key
  keydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}