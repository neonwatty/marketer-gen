import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stagesContainer", "stagesPreview"]

  connect() {
    this.updateStages()
  }

  updateStages() {
    const campaignTypeSelect = this.element.querySelector('select[name="journey[campaign_type]"]')
    if (!campaignTypeSelect || !this.hasStagesPreviewTarget) return

    const campaignType = campaignTypeSelect.value
    const stages = this.getStagesForCampaignType(campaignType)
    
    this.stagesPreviewTarget.innerHTML = ""
    
    if (stages.length > 0) {
      stages.forEach((stage, index) => {
        const stageElement = this.createStageElement(stage, index + 1)
        this.stagesPreviewTarget.appendChild(stageElement)
      })
    } else {
      this.stagesPreviewTarget.innerHTML = '<p class="text-gray-500 col-span-full text-center">Select a campaign type to see stages</p>'
    }
  }

  getStagesForCampaignType(campaignType) {
    const stageMap = {
      'awareness': ['Discovery', 'Education', 'Engagement'],
      'consideration': ['Research', 'Evaluation', 'Comparison'],
      'conversion': ['Decision', 'Purchase', 'Onboarding'],
      'retention': ['Usage', 'Support', 'Renewal'],
      'upsell_cross_sell': ['Opportunity Identification', 'Presentation', 'Closing']
    }

    return stageMap[campaignType] || []
  }

  createStageElement(stageName, stageNumber) {
    const div = document.createElement('div')
    div.className = 'flex items-center p-3 bg-gray-50 rounded-lg'
    
    div.innerHTML = `
      <div class="flex items-center justify-center w-6 h-6 bg-blue-600 text-white rounded-full text-xs font-medium mr-3">
        ${stageNumber}
      </div>
      <span class="text-sm font-medium text-gray-900">${stageName}</span>
    `
    
    return div
  }
}