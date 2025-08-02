import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: String }

  connect() {
    console.log("Tabs controller connected")
    this.showActiveTab()
  }

  switchTab(event) {
    event.preventDefault()
    
    const clickedTab = event.currentTarget
    const tabId = clickedTab.dataset.tabId
    
    if (tabId) {
      this.activeTabValue = tabId
      this.showActiveTab()
    }
  }

  showActiveTab() {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const tabId = tab.dataset.tabId
      
      if (tabId === this.activeTabValue) {
        tab.classList.add('active')
        tab.classList.remove('text-gray-500', 'border-transparent')
        tab.classList.add('text-blue-600', 'border-blue-500')
      } else {
        tab.classList.remove('active')
        tab.classList.add('text-gray-500', 'border-transparent')
        tab.classList.remove('text-blue-600', 'border-blue-500')
      }
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      const panelId = panel.dataset.tabId
      
      if (panelId === this.activeTabValue) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }

  activeTabValueChanged() {
    this.showActiveTab()
  }
}