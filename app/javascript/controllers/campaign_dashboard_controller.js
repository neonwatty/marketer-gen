import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["totalCount", "campaignList"]

  connect() {
    console.log("Campaign Dashboard controller connected!")
    this.allCampaigns = Array.from(this.campaignListTarget.querySelectorAll('.campaign-item'))
    console.log(`Managing ${this.allCampaigns.length} campaigns`)
  }

  filterBy(event) {
    const status = event.target.dataset.status
    console.log(`Filtering campaigns by status: ${status}`)
    
    // Update button states
    this.updateButtonStates(event.target)
    
    // Filter campaigns
    this.filterCampaigns(status)
    
    // Update count
    this.updateTotalCount(status)
  }

  updateButtonStates(activeButton) {
    // Reset all buttons to default state
    const allButtons = this.element.querySelectorAll('[data-action*="filterBy"]')
    allButtons.forEach(button => {
      button.className = "px-4 py-2 text-sm font-medium rounded-md bg-white text-gray-700 border hover:bg-gray-50 transition-colors"
    })
    
    // Highlight active button
    activeButton.className = "px-4 py-2 text-sm font-medium rounded-md bg-blue-100 text-blue-700 hover:bg-blue-200 transition-colors"
  }

  filterCampaigns(status) {
    this.allCampaigns.forEach(campaign => {
      const campaignStatus = campaign.dataset.status
      
      if (status === 'all' || campaignStatus === status) {
        campaign.style.display = 'block'
        // Add a subtle animation
        campaign.style.opacity = '0'
        setTimeout(() => {
          campaign.style.opacity = '1'
        }, 50)
      } else {
        campaign.style.display = 'none'
      }
    })
  }

  updateTotalCount(status) {
    let count
    
    if (status === 'all') {
      count = this.allCampaigns.length
    } else {
      count = this.allCampaigns.filter(campaign => 
        campaign.dataset.status === status
      ).length
    }
    
    this.totalCountTarget.textContent = count
    
    // Add a brief highlight effect
    this.totalCountTarget.style.color = '#3B82F6'
    setTimeout(() => {
      this.totalCountTarget.style.color = '#111827'
    }, 500)
  }
}