import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="campaign-intake"
export default class extends Controller {
  static targets = ["container", "toggle", "indicator"];
  static values = { 
    expanded: { type: Boolean, default: false },
    autoExpand: { type: Boolean, default: false },
    position: { type: String, default: "fixed" },
    completionRedirect: { type: String, default: "" }
  };

  connect() {
    console.log("Campaign Intake controller connected");
    
    // Initialize the React app
    this.initializeApp();
    
    // Set up event listeners
    this.setupEventListeners();
    
    // Auto-expand if configured
    if (this.autoExpandValue) {
      this.expand();
    }
  }

  disconnect() {
    console.log("Campaign Intake controller disconnected");
    
    // Cleanup React app
    if (this.reactRoot) {
      this.reactRoot.unmount();
      this.reactRoot = null;
    }
    
    // Remove event listeners
    this.cleanupEventListeners();
  }

  initializeApp() {
    if (window.CampaignIntake && this.hasContainerTarget) {
      try {
        this.reactRoot = window.CampaignIntake.mount(this.containerTarget.id, {
          isExpanded: this.expandedValue,
          onToggle: this.toggle.bind(this),
          className: this.getContainerClasses(),
        });
        
        console.log("Campaign Intake app mounted successfully");
      } catch (error) {
        console.error("Failed to mount Campaign Intake app:", error);
      }
    } else {
      console.error("CampaignIntake not available or container target missing");
    }
  }

  setupEventListeners() {
    // Listen for completion events
    document.addEventListener('campaign-intake:completed', this.handleCompletion.bind(this));
    document.addEventListener('campaign-intake:progress', this.handleProgress.bind(this));
    document.addEventListener('campaign-intake:error', this.handleError.bind(this));
    
    // Listen for suggestion clicks from message bubbles
    window.addEventListener('suggestion-click', this.handleSuggestionClick.bind(this));
    
    // Listen for ESC key to close
    document.addEventListener('keydown', this.handleKeydown.bind(this));
  }

  cleanupEventListeners() {
    document.removeEventListener('campaign-intake:completed', this.handleCompletion.bind(this));
    document.removeEventListener('campaign-intake:progress', this.handleProgress.bind(this));
    document.removeEventListener('campaign-intake:error', this.handleError.bind(this));
    window.removeEventListener('suggestion-click', this.handleSuggestionClick.bind(this));
    document.removeEventListener('keydown', this.handleKeydown.bind(this));
  }

  getContainerClasses() {
    const baseClasses = "campaign-intake-container";
    const positionClasses = {
      'fixed': 'fixed bottom-4 right-4 w-96 h-[600px] max-h-[80vh] z-50',
      'inline': 'w-full h-full',
      'modal': 'fixed inset-0 z-50 bg-black bg-opacity-50 flex items-center justify-center p-4'
    };
    
    return `${baseClasses} ${positionClasses[this.positionValue] || positionClasses.fixed}`;
  }

  // Actions
  toggle() {
    this.expandedValue = !this.expandedValue;
    this.updateAppState();
    this.updateIndicator();
  }

  expand() {
    this.expandedValue = true;
    this.updateAppState();
    this.updateIndicator();
  }

  collapse() {
    this.expandedValue = false;
    this.updateAppState();
    this.updateIndicator();
  }

  updateAppState() {
    if (this.reactRoot && window.CampaignIntake) {
      // Re-mount with new props
      this.reactRoot.unmount();
      this.initializeApp();
    }
  }

  updateIndicator() {
    if (this.hasIndicatorTarget) {
      const indicator = this.indicatorTarget;
      
      if (this.expandedValue) {
        indicator.classList.add('campaign-intake-expanded');
        indicator.setAttribute('aria-expanded', 'true');
      } else {
        indicator.classList.remove('campaign-intake-expanded');
        indicator.setAttribute('aria-expanded', 'false');
      }
    }
  }

  // Event Handlers
  handleCompletion(event) {
    console.log("Campaign intake completed:", event.detail);
    
    // Update indicator to show completion
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.add('campaign-intake-completed');
    }
    
    // Dispatch Rails event
    this.dispatch("completed", { 
      detail: event.detail,
      target: this.element 
    });
    
    // Redirect if configured
    if (this.completionRedirectValue) {
      setTimeout(() => {
        window.location.href = this.completionRedirectValue;
      }, 2000);
    }
  }

  handleProgress(event) {
    console.log("Campaign intake progress:", event.detail);
    
    // Update progress indicator
    if (this.hasIndicatorTarget) {
      const progress = event.detail.progress || 0;
      this.indicatorTarget.style.setProperty('--progress', `${progress}%`);
      this.indicatorTarget.setAttribute('data-progress', progress);
    }
    
    // Dispatch Rails event
    this.dispatch("progress", { 
      detail: event.detail,
      target: this.element 
    });
  }

  handleError(event) {
    console.error("Campaign intake error:", event.detail);
    
    // Add error state to indicator
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.add('campaign-intake-error');
    }
    
    // Dispatch Rails event
    this.dispatch("error", { 
      detail: event.detail,
      target: this.element 
    });
  }

  handleSuggestionClick(event) {
    console.log("Suggestion clicked:", event.detail.suggestion);
    
    // Let the React app handle this, just log for Rails integration
    this.dispatch("suggestion-clicked", { 
      detail: event.detail,
      target: this.element 
    });
  }

  handleKeydown(event) {
    // Close on ESC key if expanded
    if (event.key === 'Escape' && this.expandedValue) {
      this.collapse();
    }
  }

  // Getters for state
  get isExpanded() {
    return this.expandedValue;
  }

  get hasConversation() {
    // Check if there's an active conversation in localStorage
    try {
      const stored = sessionStorage.getItem('campaign-conversation');
      return stored && JSON.parse(stored).state?.thread?.messages?.length > 0;
    } catch (error) {
      return false;
    }
  }

  // Public API methods for other controllers
  startNewConversation() {
    // Clear existing conversation
    sessionStorage.removeItem('campaign-conversation');
    
    // Reinitialize app
    this.updateAppState();
    
    // Expand if not already
    if (!this.expandedValue) {
      this.expand();
    }
  }

  loadConversation(threadId) {
    // Trigger conversation loading
    const event = new CustomEvent('campaign-intake:load-conversation', {
      detail: { threadId }
    });
    document.dispatchEvent(event);
    
    // Expand to show loaded conversation
    if (!this.expandedValue) {
      this.expand();
    }
  }
}