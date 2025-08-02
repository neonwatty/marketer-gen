import { Controller } from "@hotwired/stimulus"

// A/B Test Form Controller
// Handles form interactions, variant management, and sample size calculations
export default class extends Controller {
  static targets = [
    "variantsContainer", "variantForm", "totalTraffic", "trafficBar", 
    "trafficInput", "templatesGrid", "sampleSizeResult", 
    "baselineRate", "mde", "power"
  ]
  
  static values = {
    templates: Array,
    variantIndex: { type: Number, default: 1 }
  }

  connect() {
    console.log("A/B Test Form connected")
    this.updateTrafficAllocation()
    this.initializeForm()
  }

  // Initialize form state
  initializeForm() {
    // Set default values if needed
    this.ensureMinimumVariants()
    this.updateTrafficAllocation()
  }

  // Add new variant
  addVariant() {
    const container = this.variantsContainerTarget
    const variantCount = this.variantFormTargets.length
    
    // Create new variant HTML
    const newVariantHtml = this.createVariantHtml(variantCount)
    container.insertAdjacentHTML('beforeend', newVariantHtml)
    
    // Redistribute traffic equally
    this.redistributeTraffic()
    this.updateTrafficAllocation()
  }

  // Remove variant
  removeVariant(event) {
    const variantIndex = event.currentTarget.dataset.variantIndex
    const variantForm = this.variantFormTargets.find(form => 
      form.dataset.variantIndex === variantIndex
    )
    
    if (variantForm && !this.isControlVariant(variantForm)) {
      // If this is a persisted record, mark for deletion
      const destroyInput = variantForm.querySelector('input[name*="_destroy"]')
      if (destroyInput) {
        destroyInput.value = '1'
        variantForm.style.display = 'none'
      } else {
        variantForm.remove()
      }
      
      // Redistribute remaining traffic
      this.redistributeTraffic()
      this.updateTrafficAllocation()
    }
  }

  // Select template
  selectTemplate(event) {
    const templateId = event.currentTarget.dataset.templateId
    const template = this.templatesValue.find(t => t.id == templateId)
    
    if (template) {
      this.applyTemplate(template)
      this.highlightSelectedTemplate(event.currentTarget)
    }
  }

  // Apply template to form
  applyTemplate(template) {
    // Fill basic information
    const nameField = this.element.querySelector('input[name="ab_test[name]"]')
    const typeField = this.element.querySelector('select[name="ab_test[test_type]"]')
    const hypothesisField = this.element.querySelector('textarea[name="ab_test[hypothesis]"]')
    const confidenceField = this.element.querySelector('select[name="ab_test[confidence_level]"]')
    const thresholdField = this.element.querySelector('input[name="ab_test[significance_threshold]"]')
    
    if (nameField && !nameField.value) {
      nameField.value = template.name
    }
    
    if (typeField) {
      typeField.value = template.test_type
    }
    
    if (hypothesisField && template.default_hypothesis) {
      hypothesisField.value = template.default_hypothesis
    }
    
    if (confidenceField) {
      confidenceField.value = template.confidence_level
    }
    
    if (thresholdField) {
      thresholdField.value = template.significance_threshold
    }
    
    // Set duration if provided
    if (template.default_duration_days) {
      const startDate = new Date()
      const endDate = new Date(startDate.getTime() + (template.default_duration_days * 24 * 60 * 60 * 1000))
      
      const startField = this.element.querySelector('input[name="ab_test[start_date]"]')
      const endField = this.element.querySelector('input[name="ab_test[end_date]"]')
      
      if (startField) {
        startField.value = this.formatDateTimeLocal(startDate)
      }
      
      if (endField) {
        endField.value = this.formatDateTimeLocal(endDate)
      }
    }
  }

  // Highlight selected template
  highlightSelectedTemplate(templateElement) {
    // Remove previous selection
    this.templatesGridTarget.querySelectorAll('.border-blue-500').forEach(el => {
      el.classList.remove('border-blue-500', 'bg-blue-50')
      el.classList.add('border-gray-200')
    })
    
    // Highlight new selection
    templateElement.classList.remove('border-gray-200')
    templateElement.classList.add('border-blue-500', 'bg-blue-50')
  }

  // Update traffic allocation display
  updateTrafficAllocation() {
    const inputs = this.trafficInputTargets
    let total = 0
    
    inputs.forEach(input => {
      const value = parseFloat(input.value) || 0
      total += value
    })
    
    // Update total display
    if (this.hasTotalTrafficTarget) {
      this.totalTrafficTarget.textContent = `${total.toFixed(1)}%`
      
      // Color coding based on total
      if (total === 100) {
        this.totalTrafficTarget.className = 'text-lg font-bold text-green-600'
      } else if (total > 100) {
        this.totalTrafficTarget.className = 'text-lg font-bold text-red-600'
      } else {
        this.totalTrafficTarget.className = 'text-lg font-bold text-yellow-600'
      }
    }
    
    // Update progress bar
    if (this.hasTrafficBarTarget) {
      const percentage = Math.min(total, 100)
      this.trafficBarTarget.style.width = `${percentage}%`
      
      // Color progress bar
      if (total === 100) {
        this.trafficBarTarget.className = 'bg-green-600 h-2 rounded-full transition-all duration-300'
      } else if (total > 100) {
        this.trafficBarTarget.className = 'bg-red-600 h-2 rounded-full transition-all duration-300'
      } else {
        this.trafficBarTarget.className = 'bg-yellow-600 h-2 rounded-full transition-all duration-300'
      }
    }
    
    // Validate traffic allocation
    this.validateTrafficAllocation(total)
  }

  // Validate traffic allocation
  validateTrafficAllocation(total) {
    const isValid = total >= 99 && total <= 101 // Allow 1% tolerance
    
    this.trafficInputTargets.forEach(input => {
      if (isValid) {
        input.classList.remove('border-red-300', 'text-red-900')
        input.classList.add('border-gray-300')
      } else {
        input.classList.remove('border-gray-300')
        input.classList.add('border-red-300', 'text-red-900')
      }
    })
  }

  // Redistribute traffic equally among variants
  redistributeTraffic() {
    const visibleVariants = this.variantFormTargets.filter(form => 
      form.style.display !== 'none'
    )
    const trafficPerVariant = Math.floor(100 / visibleVariants.length)
    const remainder = 100 - (trafficPerVariant * visibleVariants.length)
    
    visibleVariants.forEach((form, index) => {
      const input = form.querySelector('input[name*="traffic_percentage"]')
      if (input) {
        let value = trafficPerVariant
        // Add remainder to first variant
        if (index === 0) value += remainder
        input.value = value
      }
    })
  }

  // Calculate sample size
  calculateSampleSize() {
    const baselineRate = parseFloat(this.baselineRateTarget.value) || 5
    const mde = parseFloat(this.mdeTarget.value) || 20
    const power = parseInt(this.powerTarget.value) || 80
    const confidenceLevel = parseFloat(document.querySelector('select[name="ab_test[confidence_level]"]')?.value) || 95
    
    // Basic sample size calculation (simplified)
    const alpha = (100 - confidenceLevel) / 100
    const beta = (100 - power) / 100
    
    const p1 = baselineRate / 100
    const p2 = p1 * (1 + mde / 100)
    
    const pooledP = (p1 + p2) / 2
    const effectSize = Math.abs(p2 - p1)
    
    // Z-scores (approximated)
    const zAlpha = confidenceLevel === 95 ? 1.96 : confidenceLevel === 90 ? 1.645 : 2.576
    const zBeta = power === 80 ? 0.84 : power === 90 ? 1.28 : 1.645
    
    const sampleSizePerVariant = Math.ceil(
      (2 * pooledP * (1 - pooledP) * Math.pow(zAlpha + zBeta, 2)) / Math.pow(effectSize, 2)
    )
    
    const totalSampleSize = sampleSizePerVariant * 2 // For 2 variants
    
    // Update result display
    this.sampleSizeResultTarget.innerHTML = `
      <div class="grid grid-cols-2 gap-4">
        <div>
          <div class="text-sm font-medium text-blue-800">Per Variant</div>
          <div class="text-lg font-bold text-blue-900">${sampleSizePerVariant.toLocaleString()}</div>
        </div>
        <div>
          <div class="text-sm font-medium text-blue-800">Total Needed</div>
          <div class="text-lg font-bold text-blue-900">${totalSampleSize.toLocaleString()}</div>
        </div>
      </div>
      <div class="mt-2 text-xs text-blue-600">
        Based on ${baselineRate}% baseline rate, ${mde}% minimum detectable effect, 
        ${power}% power, ${confidenceLevel}% confidence
      </div>
    `
    
    // Auto-fill minimum sample size if empty
    const minSampleField = document.querySelector('input[name="ab_test[minimum_sample_size]"]')
    if (minSampleField && !minSampleField.value) {
      minSampleField.value = totalSampleSize
    }
  }

  // Toggle templates visibility
  toggleTemplates() {
    const grid = this.templatesGridTarget
    const button = event.currentTarget
    
    if (grid.children.length > 3) {
      // Show/hide additional templates
      for (let i = 3; i < grid.children.length; i++) {
        const template = grid.children[i]
        if (template.style.display === 'none') {
          template.style.display = 'block'
          button.textContent = 'Show Less'
        } else {
          template.style.display = 'none'
          button.textContent = 'Show All Templates'
        }
      }
    }
  }

  // Helper methods
  isControlVariant(form) {
    const controlInput = form.querySelector('input[name*="is_control"]')
    return controlInput && controlInput.value === 'true'
  }

  ensureMinimumVariants() {
    if (this.variantFormTargets.length < 2) {
      // Ensure we have at least control and one treatment
      const hasControl = this.variantFormTargets.some(form => this.isControlVariant(form))
      if (!hasControl) {
        this.addControlVariant()
      }
      
      if (this.variantFormTargets.length < 2) {
        this.addVariant()
      }
    }
  }

  formatDateTimeLocal(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    
    return `${year}-${month}-${day}T${hours}:${minutes}`
  }

  createVariantHtml(index) {
    // This would normally be rendered from a template
    // For now, return placeholder HTML
    return `
      <div class="border border-gray-200 rounded-lg p-4 mb-4" 
           data-ab-test-form-target="variantForm"
           data-variant-index="${index}">
        <div class="text-center py-4">
          <p class="text-gray-500">New variant form would be added here</p>
          <p class="text-sm text-gray-400">This requires server-side template rendering</p>
        </div>
      </div>
    `
  }
}