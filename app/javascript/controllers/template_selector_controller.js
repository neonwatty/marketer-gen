import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-selector"
export default class extends Controller {
  static targets = ["guidedQuestions", "templatesGrid", "templateCard", "previewModal", "previewContent"]

  connect() {
    console.log("Template selector controller connected")
    
    // Setup keyboard navigation
    this.setupKeyboardNavigation()
    
    // Setup intersection observer for lazy loading
    this.setupIntersectionObserver()
  }

  disconnect() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
  }

  // Handle guided question responses
  handleQuestionResponse(event) {
    // Add loading state to the question area
    const questionArea = this.guidedQuestionsTarget
    questionArea.classList.add("opacity-50", "pointer-events-none")
    
    // Add spinner or loading indicator
    const loader = document.createElement("div")
    loader.className = "absolute inset-0 flex items-center justify-center bg-white bg-opacity-75"
    loader.innerHTML = '<div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>'
    questionArea.style.position = "relative"
    questionArea.appendChild(loader)
    
    // The form submission will be handled by Turbo
    // We just need to clean up the loading state after response
    setTimeout(() => {
      questionArea.classList.remove("opacity-50", "pointer-events-none")
      if (loader.parentNode) {
        loader.remove()
      }
    }, 1000)
  }

  // Show template preview in modal
  showPreview(event) {
    const templateId = event.currentTarget.dataset.templateId
    if (!templateId) return

    // Show modal
    this.previewModalTarget.classList.remove("hidden")
    
    // Add loading state
    this.previewContentTarget.innerHTML = this.getLoadingHTML()
    
    // Fetch preview content
    fetch(`/journeys/${templateId}/template_preview`, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => response.text())
    .then(html => {
      this.previewContentTarget.innerHTML = html
    })
    .catch(error => {
      console.error("Error loading template preview:", error)
      this.previewContentTarget.innerHTML = this.getErrorHTML()
    })
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Setup modal close on escape key
    this.boundEscapeHandler = this.handleEscapeKey.bind(this)
    document.addEventListener("keydown", this.boundEscapeHandler)
    
    // Setup modal close on backdrop click
    this.boundBackdropHandler = this.handleBackdropClick.bind(this)
    this.previewModalTarget.addEventListener("click", this.boundBackdropHandler)
  }

  // Close template preview modal
  closePreview() {
    this.previewModalTarget.classList.add("hidden")
    document.body.style.overflow = ""
    
    // Clean up event listeners
    if (this.boundEscapeHandler) {
      document.removeEventListener("keydown", this.boundEscapeHandler)
      this.boundEscapeHandler = null
    }
    
    if (this.boundBackdropHandler) {
      this.previewModalTarget.removeEventListener("click", this.boundBackdropHandler)
      this.boundBackdropHandler = null
    }
  }

  // Handle escape key to close modal
  handleEscapeKey(event) {
    if (event.key === "Escape") {
      this.closePreview()
    }
  }

  // Handle backdrop click to close modal
  handleBackdropClick(event) {
    if (event.target === this.previewModalTarget) {
      this.closePreview()
    }
  }

  // Setup keyboard navigation for template cards
  setupKeyboardNavigation() {
    if (!this.hasTemplatesGridTarget) return

    this.templatesGridTarget.addEventListener("keydown", (event) => {
      const focusedCard = document.activeElement.closest("[data-template-selector-target='templateCard']")
      if (!focusedCard) return

      const cards = Array.from(this.templateCardTargets)
      const currentIndex = cards.indexOf(focusedCard)

      switch (event.key) {
        case "ArrowRight":
        case "ArrowDown":
          event.preventDefault()
          this.focusCard(cards, currentIndex + 1)
          break
        case "ArrowLeft":
        case "ArrowUp":
          event.preventDefault()
          this.focusCard(cards, currentIndex - 1)
          break
        case "Enter":
        case " ":
          event.preventDefault()
          const previewButton = focusedCard.querySelector("[data-action*='showPreview']")
          if (previewButton) {
            previewButton.click()
          }
          break
      }
    })

    // Make template cards focusable
    this.templateCardTargets.forEach((card, index) => {
      card.setAttribute("tabindex", index === 0 ? "0" : "-1")
      card.addEventListener("focus", () => {
        this.templateCardTargets.forEach(c => c.setAttribute("tabindex", "-1"))
        card.setAttribute("tabindex", "0")
      })
    })
  }

  // Focus a specific template card
  focusCard(cards, index) {
    const targetIndex = Math.max(0, Math.min(index, cards.length - 1))
    const targetCard = cards[targetIndex]
    if (targetCard) {
      targetCard.focus()
    }
  }

  // Setup intersection observer for performance
  setupIntersectionObserver() {
    if (!this.hasTemplatesGridTarget || !("IntersectionObserver" in window)) return

    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("animate-fade-in")
        }
      })
    }, {
      threshold: 0.1,
      rootMargin: "50px"
    })

    this.templateCardTargets.forEach((card) => {
      this.intersectionObserver.observe(card)
    })
  }

  // Add animation classes when cards become visible
  templateCardTargetConnected(element) {
    if (this.intersectionObserver) {
      this.intersectionObserver.observe(element)
    }
  }

  templateCardTargetDisconnected(element) {
    if (this.intersectionObserver) {
      this.intersectionObserver.unobserve(element)
    }
  }

  // Utility methods for modal content
  getLoadingHTML() {
    return `
      <div class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="ml-3 text-gray-600">Loading template preview...</span>
      </div>
    `
  }

  getErrorHTML() {
    return `
      <div class="text-center py-12">
        <div class="mb-4">
          <i class="lucide-alert-circle w-12 h-12 text-red-400 mx-auto"></i>
        </div>
        <h3 class="text-lg font-medium text-gray-900 mb-2">Preview Unavailable</h3>
        <p class="text-gray-600 mb-4">Sorry, we couldn't load the template preview. Please try again.</p>
        <button type="button" 
                data-action="click->template-selector#closePreview"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-4 rounded-lg transition-colors">
          Close
        </button>
      </div>
    `
  }
}