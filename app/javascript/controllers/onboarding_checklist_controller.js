import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="onboarding-checklist"
export default class extends Controller {
  static targets = ["progress", "progressText", "checklist", "step", "nextAction"]
  static values = { 
    endpoint: String,
    refreshInterval: { type: Number, default: 30000 }, // 30 seconds
    autoRefresh: { type: Boolean, default: true }
  }

  connect() {
    this.refreshProgress()
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  async refreshProgress() {
    if (!this.endpointValue) return

    try {
      const response = await fetch(this.endpointValue, {
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`)
      
      const data = await response.json()
      this.updateProgress(data.onboarding)
    } catch (error) {
      console.error('Error fetching onboarding progress:', error)
    }
  }

  updateProgress(progressData) {
    const { completion_percentage, completed_steps, next_suggested_action, missing_essentials } = progressData

    // Update progress bar
    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${completion_percentage}%`
      this.progressTarget.setAttribute('aria-valuenow', completion_percentage)
    }

    // Update progress text
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${completion_percentage}% complete`
    }

    // Update step checkmarks
    this.stepTargets.forEach(stepElement => {
      const stepName = stepElement.dataset.step
      const isCompleted = completed_steps.includes(stepName)
      this.updateStepStatus(stepElement, isCompleted)
    })

    // Update next action
    if (this.hasNextActionTarget && next_suggested_action) {
      this.updateNextAction(next_suggested_action, missing_essentials)
    }

    // Show/hide completed state
    const isFullyComplete = completion_percentage >= 100
    this.element.classList.toggle('onboarding-complete', isFullyComplete)
    
    if (isFullyComplete) {
      this.showCompletionState()
    }
  }

  updateStepStatus(stepElement, isCompleted) {
    const checkbox = stepElement.querySelector('[data-onboarding-step="checkbox"]')
    const icon = stepElement.querySelector('[data-onboarding-step="icon"]')
    const text = stepElement.querySelector('[data-onboarding-step="text"]')

    stepElement.classList.toggle('completed', isCompleted)
    
    if (checkbox) {
      checkbox.checked = isCompleted
    }

    if (icon) {
      icon.innerHTML = isCompleted 
        ? this.getCheckmarkIcon() 
        : this.getPendingIcon()
    }

    if (text) {
      text.classList.toggle('line-through', isCompleted)
      text.classList.toggle('text-gray-500', isCompleted)
    }
  }

  updateNextAction(nextAction, missingEssentials) {
    const actionConfig = this.getActionConfig(nextAction)
    
    this.nextActionTarget.innerHTML = `
      <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${this.getActionIcon(nextAction)}
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-blue-800">
              Next: ${actionConfig.title}
            </h3>
            <p class="mt-1 text-sm text-blue-700">
              ${actionConfig.description}
            </p>
            ${actionConfig.actionUrl ? `
              <div class="mt-3">
                <a href="${actionConfig.actionUrl}" 
                   class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors">
                  ${actionConfig.actionText}
                  <svg class="ml-2 -mr-0.5 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                  </svg>
                </a>
              </div>
            ` : ''}
          </div>
        </div>
      </div>
    `
  }

  getActionConfig(action) {
    const configs = {
      complete_profile: {
        title: "Complete Your Profile",
        description: "Add your company and role information to get personalized suggestions.",
        actionUrl: "/profile/edit",
        actionText: "Complete Profile"
      },
      create_brand_identity: {
        title: "Create Brand Identity",
        description: "Set up your brand voice, colors, and messaging guidelines.",
        actionUrl: "/brand_identities/new",
        actionText: "Create Brand Identity"
      },
      create_first_campaign: {
        title: "Create Your First Campaign",
        description: "Build your first marketing campaign plan with our guided process.",
        actionUrl: "/campaign_plans/new",
        actionText: "Create Campaign"
      },
      generate_campaign_plan: {
        title: "Generate Campaign Plan",
        description: "Complete your draft campaign by generating the full plan.",
        actionUrl: "/campaign_plans",
        actionText: "View Campaigns"
      },
      create_first_journey: {
        title: "Create Customer Journey",
        description: "Map out your customer touchpoints and engagement flow.",
        actionUrl: "/journeys/new",
        actionText: "Create Journey"
      },
      generate_content: {
        title: "Generate Content",
        description: "Create marketing content for your campaigns.",
        actionUrl: "/generated_contents",
        actionText: "Generate Content"
      },
      explore_features: {
        title: "Explore Advanced Features",
        description: "You're all set up! Explore analytics, integrations, and more.",
        actionUrl: "/help",
        actionText: "Explore Features"
      }
    }

    return configs[action] || {
      title: "Continue Setup",
      description: "Complete your account setup to get the most from the platform.",
      actionUrl: null,
      actionText: "Continue"
    }
  }

  showCompletionState() {
    if (this.hasNextActionTarget) {
      this.nextActionTarget.innerHTML = `
        <div class="bg-green-50 border border-green-200 rounded-md p-4">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-green-800">
                🎉 Setup Complete!
              </h3>
              <p class="mt-1 text-sm text-green-700">
                You're all set up and ready to create amazing marketing campaigns. 
                Explore analytics, integrations, and advanced features.
              </p>
              <div class="mt-3">
                <a href="/help" 
                   class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors">
                  Explore Features
                  <svg class="ml-2 -mr-0.5 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                  </svg>
                </a>
              </div>
            </div>
          </div>
        </div>
      `
    }
  }

  dismissChecklist() {
    // Store dismissed state in localStorage
    localStorage.setItem('onboarding-checklist-dismissed', 'true')
    this.element.classList.add('hidden')
    
    // Dispatch custom event for analytics
    this.dispatch('dismissed', { detail: { completion_percentage: this.getCurrentCompletion() } })
  }

  expandChecklist() {
    if (this.hasChecklistTarget) {
      this.checklistTarget.classList.remove('hidden')
    }
    this.element.classList.remove('collapsed')
    this.element.classList.add('expanded')
    
    // Store preference
    localStorage.setItem('onboarding-checklist-expanded', 'true')
  }

  collapseChecklist() {
    if (this.hasChecklistTarget) {
      this.checklistTarget.classList.add('hidden')
    }
    this.element.classList.remove('expanded')
    this.element.classList.add('collapsed')
    
    // Store preference
    localStorage.setItem('onboarding-checklist-expanded', 'false')
  }

  getCurrentCompletion() {
    if (this.hasProgressTarget) {
      return parseInt(this.progressTarget.getAttribute('aria-valuenow') || '0')
    }
    return 0
  }

  startAutoRefresh() {
    this.refreshIntervalId = setInterval(() => {
      this.refreshProgress()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshIntervalId) {
      clearInterval(this.refreshIntervalId)
      this.refreshIntervalId = null
    }
  }

  // Icon helpers
  getCheckmarkIcon() {
    return `
      <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
    `
  }

  getPendingIcon() {
    return `
      <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
    `
  }

  getActionIcon(action) {
    const icons = {
      complete_profile: `<svg class="h-5 w-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
      </svg>`,
      create_brand_identity: `<svg class="h-5 w-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>
      </svg>`,
      create_first_campaign: `<svg class="h-5 w-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"></path>
      </svg>`
    }
    
    return icons[action] || `<svg class="h-5 w-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
    </svg>`
  }
}