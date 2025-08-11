import { Controller } from "@hotwired/stimulus"

// Stage Configuration Controller for dynamic form fields based on stage type
export default class extends Controller {
  static targets = [
    "form", "dynamicFieldsContainer", 
    "stageNameInput", "stageDescriptionInput", "stageDurationInput",
    "errorContainer", "saveButton", "cancelButton"
  ]

  static values = {
    stageData: Object,
    stageTypes: Array
  }

  connect() {
    this.currentStage = this.stageDataValue || {}
    this.validationRules = {}
    this.fieldConfigurations = this.getFieldConfigurations()
    
    // Initialize form if stage data exists
    if (Object.keys(this.currentStage).length > 0) {
      this.populateForm()
    }
    
    this.setupEventListeners()
    this.updateDynamicFields()
  }

  // Setup additional event listeners
  setupEventListeners() {
    // Real-time validation
    this.formTarget.addEventListener('input', this.handleFieldInput.bind(this))
    this.formTarget.addEventListener('change', this.handleFieldChange.bind(this))
    
    // Form submission
    this.formTarget.addEventListener('submit', this.handleFormSubmit.bind(this))
  }

  // Handle stage type change
  handleStageTypeChange(event) {
    const stageType = event.target.value
    this.currentStage.type = stageType
    this.updateDynamicFields()
    this.clearErrors()
  }

  // Update dynamic fields based on stage type
  updateDynamicFields() {
    const stageType = this.currentStage.type
    if (!stageType) return

    const fieldConfig = this.fieldConfigurations[stageType] || this.fieldConfigurations.default
    this.renderDynamicFields(fieldConfig)
  }

  // Render dynamic fields based on configuration
  renderDynamicFields(fieldConfig) {
    if (!this.hasDynamicFieldsContainerTarget) return

    let fieldsHTML = ''

    fieldConfig.sections.forEach(section => {
      fieldsHTML += this.renderSection(section)
    })

    this.dynamicFieldsContainerTarget.innerHTML = fieldsHTML
    this.initializeFieldComponents()
  }

  // Render a form section
  renderSection(section) {
    let sectionHTML = `
      <div class="stage-config-section mt-6 pt-6 border-t border-gray-200">
        <h4 class="text-base font-medium text-gray-900 mb-4">${section.title}</h4>
    `

    if (section.description) {
      sectionHTML += `
        <p class="text-sm text-gray-600 mb-4">${section.description}</p>
      `
    }

    section.fields.forEach(field => {
      sectionHTML += this.renderField(field)
    })

    sectionHTML += '</div>'
    return sectionHTML
  }

  // Render individual field based on type
  renderField(field) {
    const value = this.getFieldValue(field.name)
    const isRequired = field.required ? 'required' : ''
    const fieldId = `stage_config_${field.name}`

    switch (field.type) {
      case 'text':
        return this.renderTextField(field, value, fieldId, isRequired)
      case 'textarea':
        return this.renderTextareaField(field, value, fieldId, isRequired)
      case 'richtext':
        return this.renderRichTextField(field, value, fieldId, isRequired)
      case 'select':
        return this.renderSelectField(field, value, fieldId, isRequired)
      case 'multiselect':
        return this.renderMultiSelectField(field, value, fieldId, isRequired)
      case 'checkbox':
        return this.renderCheckboxField(field, value, fieldId)
      case 'number':
        return this.renderNumberField(field, value, fieldId, isRequired)
      case 'date':
        return this.renderDateField(field, value, fieldId, isRequired)
      case 'time':
        return this.renderTimeField(field, value, fieldId, isRequired)
      case 'datetime':
        return this.renderDateTimeField(field, value, fieldId, isRequired)
      case 'color':
        return this.renderColorField(field, value, fieldId, isRequired)
      case 'json':
        return this.renderJsonField(field, value, fieldId, isRequired)
      default:
        return this.renderTextField(field, value, fieldId, isRequired)
    }
  }

  // Field rendering methods
  renderTextField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <input type="text" 
               id="${fieldId}"
               name="${field.name}"
               value="${value || ''}"
               placeholder="${field.placeholder || ''}"
               ${isRequired}
               class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
               data-field-type="text">
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderTextareaField(field, value, fieldId, isRequired) {
    const rows = field.rows || 3
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <textarea id="${fieldId}"
                  name="${field.name}"
                  rows="${rows}"
                  placeholder="${field.placeholder || ''}"
                  ${isRequired}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  data-field-type="textarea">${value || ''}</textarea>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderRichTextField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <div class="rich-text-editor border border-gray-300 rounded-md">
          <textarea id="${fieldId}"
                    name="${field.name}"
                    ${isRequired}
                    class="hidden"
                    data-field-type="richtext">${value || ''}</textarea>
          <div class="rich-text-toolbar bg-gray-50 border-b border-gray-300 p-2 flex space-x-2">
            <button type="button" class="rich-text-btn" data-command="bold">B</button>
            <button type="button" class="rich-text-btn" data-command="italic">I</button>
            <button type="button" class="rich-text-btn" data-command="underline">U</button>
          </div>
          <div contenteditable="true" 
               class="rich-text-content p-3 min-h-[100px] focus:outline-none"
               data-target-textarea="${fieldId}">${value || ''}</div>
        </div>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderSelectField(field, value, fieldId, isRequired) {
    let optionsHTML = field.placeholder ? `<option value="">${field.placeholder}</option>` : ''
    
    field.options.forEach(option => {
      const optionValue = typeof option === 'object' ? option.value : option
      const optionLabel = typeof option === 'object' ? option.label : option
      const selected = value === optionValue ? 'selected' : ''
      optionsHTML += `<option value="${optionValue}" ${selected}>${optionLabel}</option>`
    })

    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <select id="${fieldId}"
                name="${field.name}"
                ${isRequired}
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                data-field-type="select">
          ${optionsHTML}
        </select>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderMultiSelectField(field, value, fieldId, isRequired) {
    const values = Array.isArray(value) ? value : (value ? [value] : [])
    
    let optionsHTML = ''
    field.options.forEach(option => {
      const optionValue = typeof option === 'object' ? option.value : option
      const optionLabel = typeof option === 'object' ? option.label : option
      const checked = values.includes(optionValue) ? 'checked' : ''
      
      optionsHTML += `
        <label class="inline-flex items-center mr-4 mb-2">
          <input type="checkbox" 
                 name="${field.name}[]" 
                 value="${optionValue}" 
                 ${checked}
                 class="rounded border-gray-300 text-blue-600 shadow-sm focus:ring-blue-500">
          <span class="ml-2 text-sm text-gray-700">${optionLabel}</span>
        </label>
      `
    })

    return `
      <div class="form-field mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <div class="space-y-2" data-field-type="multiselect">
          ${optionsHTML}
        </div>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderCheckboxField(field, value, fieldId) {
    const checked = value ? 'checked' : ''
    
    return `
      <div class="form-field mb-4">
        <label class="inline-flex items-center">
          <input type="checkbox" 
                 id="${fieldId}"
                 name="${field.name}" 
                 value="1" 
                 ${checked}
                 class="rounded border-gray-300 text-blue-600 shadow-sm focus:ring-blue-500"
                 data-field-type="checkbox">
          <span class="ml-2 text-sm text-gray-700">${field.label}</span>
        </label>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderNumberField(field, value, fieldId, isRequired) {
    const min = field.min !== undefined ? `min="${field.min}"` : ''
    const max = field.max !== undefined ? `max="${field.max}"` : ''
    const step = field.step !== undefined ? `step="${field.step}"` : ''
    
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <input type="number" 
               id="${fieldId}"
               name="${field.name}"
               value="${value || ''}"
               placeholder="${field.placeholder || ''}"
               ${min} ${max} ${step}
               ${isRequired}
               class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
               data-field-type="number">
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderDateField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <input type="date" 
               id="${fieldId}"
               name="${field.name}"
               value="${value || ''}"
               ${isRequired}
               class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
               data-field-type="date">
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderTimeField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <input type="time" 
               id="${fieldId}"
               name="${field.name}"
               value="${value || ''}"
               ${isRequired}
               class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
               data-field-type="time">
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderDateTimeField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <input type="datetime-local" 
               id="${fieldId}"
               name="${field.name}"
               value="${value || ''}"
               ${isRequired}
               class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
               data-field-type="datetime">
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderColorField(field, value, fieldId, isRequired) {
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <div class="flex space-x-2">
          <input type="color" 
                 id="${fieldId}"
                 name="${field.name}"
                 value="${value || '#000000'}"
                 ${isRequired}
                 class="h-10 w-16 border border-gray-300 rounded-md"
                 data-field-type="color">
          <input type="text" 
                 value="${value || '#000000'}"
                 class="flex-1 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                 data-color-text="${fieldId}">
        </div>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  renderJsonField(field, value, fieldId, isRequired) {
    const jsonValue = typeof value === 'object' ? JSON.stringify(value, null, 2) : (value || '{}')
    
    return `
      <div class="form-field mb-4">
        <label for="${fieldId}" class="block text-sm font-medium text-gray-700 mb-1">
          ${field.label} ${field.required ? '<span class="text-red-500">*</span>' : ''}
        </label>
        <textarea id="${fieldId}"
                  name="${field.name}"
                  rows="6"
                  placeholder="${field.placeholder || '{}'}"
                  ${isRequired}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 font-mono text-sm"
                  data-field-type="json">${jsonValue}</textarea>
        ${field.help ? `<p class="mt-1 text-xs text-gray-500">${field.help}</p>` : ''}
        <div class="field-error text-red-500 text-xs mt-1 hidden"></div>
      </div>
    `
  }

  // Initialize field components after rendering
  initializeFieldComponents() {
    this.initializeRichTextEditors()
    this.initializeColorPickers()
    this.initializeJsonEditors()
  }

  // Initialize rich text editors
  initializeRichTextEditors() {
    this.element.querySelectorAll('[data-field-type="richtext"]').forEach(field => {
      const content = field.parentElement.querySelector('.rich-text-content')
      const toolbar = field.parentElement.querySelector('.rich-text-toolbar')
      
      // Toolbar button handlers
      toolbar.addEventListener('click', (e) => {
        if (e.target.classList.contains('rich-text-btn')) {
          e.preventDefault()
          const command = e.target.dataset.command
          document.execCommand(command, false, null)
          content.focus()
        }
      })
      
      // Update hidden field on content change
      content.addEventListener('input', () => {
        field.value = content.innerHTML
      })
    })
  }

  // Initialize color pickers
  initializeColorPickers() {
    this.element.querySelectorAll('[data-field-type="color"]').forEach(colorInput => {
      const textInput = this.element.querySelector(`[data-color-text="${colorInput.id}"]`)
      
      if (textInput) {
        colorInput.addEventListener('change', () => {
          textInput.value = colorInput.value
        })
        
        textInput.addEventListener('input', () => {
          if (/^#[0-9A-F]{6}$/i.test(textInput.value)) {
            colorInput.value = textInput.value
          }
        })
      }
    })
  }

  // Initialize JSON editors with validation
  initializeJsonEditors() {
    this.element.querySelectorAll('[data-field-type="json"]').forEach(jsonField => {
      jsonField.addEventListener('blur', () => {
        try {
          const parsed = JSON.parse(jsonField.value || '{}')
          jsonField.value = JSON.stringify(parsed, null, 2)
          this.clearFieldError(jsonField)
        } catch (error) {
          this.setFieldError(jsonField, 'Invalid JSON format')
        }
      })
    })
  }

  // Get field configurations based on stage type
  getFieldConfigurations() {
    return {
      awareness: {
        sections: [
          {
            title: 'Content Configuration',
            description: 'Define the content and messaging for this awareness stage',
            fields: [
              { name: 'content_type', label: 'Content Type', type: 'select', required: true, 
                options: ['blog_post', 'social_media', 'advertisement', 'video', 'podcast', 'infographic'], 
                help: 'Primary content format for this stage' },
              { name: 'headline', label: 'Primary Headline', type: 'text', required: true, 
                placeholder: 'Enter compelling headline...' },
              { name: 'content', label: 'Content Body', type: 'richtext', required: true, 
                help: 'Main content or message for this stage' },
              { name: 'cta_text', label: 'Call-to-Action', type: 'text', 
                placeholder: 'Learn More', help: 'Button or link text' },
              { name: 'cta_url', label: 'CTA URL', type: 'text', 
                placeholder: 'https://...', help: 'Destination URL for the call-to-action' }
            ]
          },
          {
            title: 'Channel & Distribution',
            fields: [
              { name: 'channels', label: 'Distribution Channels', type: 'multiselect', required: true,
                options: ['email', 'social_media', 'blog', 'paid_ads', 'seo', 'pr', 'events'], 
                help: 'Where this content will be distributed' },
              { name: 'social_platforms', label: 'Social Platforms', type: 'multiselect',
                options: ['facebook', 'twitter', 'linkedin', 'instagram', 'youtube', 'tiktok'] },
              { name: 'ad_budget', label: 'Advertising Budget', type: 'number', min: 0, step: 100,
                help: 'Budget allocation for paid promotion' }
            ]
          },
          {
            title: 'Audience & Targeting',
            fields: [
              { name: 'target_audience', label: 'Target Audience', type: 'textarea', required: true,
                placeholder: 'Describe your target audience...', rows: 3 },
              { name: 'demographics', label: 'Demographics', type: 'json',
                placeholder: '{"age_range": "25-45", "location": "US"}',
                help: 'Demographic targeting criteria in JSON format' },
              { name: 'interests', label: 'Interest Targeting', type: 'text',
                placeholder: 'technology, marketing, business', 
                help: 'Comma-separated list of interests' }
            ]
          },
          {
            title: 'Success Metrics',
            fields: [
              { name: 'primary_metric', label: 'Primary Success Metric', type: 'select', required: true,
                options: ['impressions', 'reach', 'engagement', 'clicks', 'brand_awareness', 'website_traffic'] },
              { name: 'target_impressions', label: 'Target Impressions', type: 'number', min: 1000 },
              { name: 'target_engagement_rate', label: 'Target Engagement Rate (%)', type: 'number', min: 0, max: 100, step: 0.1 },
              { name: 'tracking_pixels', label: 'Tracking Pixels', type: 'textarea', rows: 2,
                help: 'Analytics and tracking code snippets' }
            ]
          }
        ]
      },
      consideration: {
        sections: [
          {
            title: 'Educational Content',
            fields: [
              { name: 'content_type', label: 'Content Type', type: 'select', required: true,
                options: ['whitepaper', 'case_study', 'webinar', 'demo', 'comparison_guide', 'tutorial'] },
              { name: 'title', label: 'Content Title', type: 'text', required: true },
              { name: 'content', label: 'Content Body', type: 'richtext', required: true },
              { name: 'lead_magnet', label: 'Is this a lead magnet?', type: 'checkbox',
                help: 'Requires form submission to access content' },
              { name: 'download_url', label: 'Download URL', type: 'text',
                help: 'URL for downloadable content' }
            ]
          },
          {
            title: 'Lead Nurturing',
            fields: [
              { name: 'nurture_sequence', label: 'Nurture Email Sequence', type: 'json',
                help: 'Define follow-up email sequence in JSON format' },
              { name: 'scoring_rules', label: 'Lead Scoring Rules', type: 'json',
                help: 'Points awarded for different actions' },
              { name: 'qualification_criteria', label: 'Qualification Criteria', type: 'textarea', rows: 3,
                help: 'Define what makes a qualified lead' }
            ]
          },
          {
            title: 'Personalization',
            fields: [
              { name: 'personalization_fields', label: 'Personalization Fields', type: 'multiselect',
                options: ['name', 'company', 'industry', 'role', 'company_size', 'interests'] },
              { name: 'dynamic_content', label: 'Dynamic Content Rules', type: 'json',
                help: 'Rules for showing different content based on user attributes' }
            ]
          }
        ]
      },
      conversion: {
        sections: [
          {
            title: 'Conversion Setup',
            fields: [
              { name: 'conversion_type', label: 'Conversion Type', type: 'select', required: true,
                options: ['purchase', 'signup', 'demo_request', 'consultation', 'trial', 'download'] },
              { name: 'conversion_page', label: 'Conversion Page URL', type: 'text', required: true,
                placeholder: 'https://...', help: 'Landing page or form URL' },
              { name: 'offer_details', label: 'Offer Details', type: 'richtext',
                help: 'Describe the offer or value proposition' }
            ]
          },
          {
            title: 'Urgency & Incentives',
            fields: [
              { name: 'urgency_type', label: 'Urgency Type', type: 'select',
                options: ['limited_time', 'limited_quantity', 'early_bird', 'seasonal', 'none'] },
              { name: 'deadline', label: 'Offer Deadline', type: 'datetime' },
              { name: 'discount_percentage', label: 'Discount Percentage', type: 'number', min: 0, max: 100 },
              { name: 'bonus_items', label: 'Bonus Items', type: 'textarea', rows: 2,
                help: 'Additional incentives or bonuses' }
            ]
          },
          {
            title: 'Form & Checkout',
            fields: [
              { name: 'form_fields', label: 'Required Form Fields', type: 'multiselect',
                options: ['name', 'email', 'phone', 'company', 'role', 'budget', 'timeline'] },
              { name: 'payment_methods', label: 'Payment Methods', type: 'multiselect',
                options: ['credit_card', 'paypal', 'stripe', 'bank_transfer', 'check'] },
              { name: 'confirmation_message', label: 'Confirmation Message', type: 'richtext',
                help: 'Message shown after successful conversion' }
            ]
          },
          {
            title: 'Follow-up',
            fields: [
              { name: 'immediate_followup', label: 'Immediate Follow-up', type: 'richtext',
                help: 'Email or message sent immediately after conversion' },
              { name: 'fulfillment_process', label: 'Fulfillment Process', type: 'textarea', rows: 3,
                help: 'Steps for delivering the product/service' },
              { name: 'onboarding_sequence', label: 'Onboarding Sequence', type: 'json',
                help: 'Next steps and onboarding process' }
            ]
          }
        ]
      },
      retention: {
        sections: [
          {
            title: 'Retention Strategy',
            fields: [
              { name: 'retention_type', label: 'Retention Type', type: 'select', required: true,
                options: ['onboarding', 'education', 'support', 'loyalty_program', 'upsell', 'community'] },
              { name: 'touchpoint_frequency', label: 'Touchpoint Frequency', type: 'select', required: true,
                options: ['daily', 'weekly', 'bi-weekly', 'monthly', 'quarterly', 'as_needed'] },
              { name: 'retention_content', label: 'Retention Content', type: 'richtext', required: true }
            ]
          },
          {
            title: 'Customer Success',
            fields: [
              { name: 'success_metrics', label: 'Success Metrics', type: 'multiselect',
                options: ['product_usage', 'support_tickets', 'satisfaction_score', 'feature_adoption'] },
              { name: 'health_score_factors', label: 'Health Score Factors', type: 'json',
                help: 'Factors that contribute to customer health scoring' },
              { name: 'intervention_triggers', label: 'Intervention Triggers', type: 'textarea', rows: 3,
                help: 'Conditions that trigger proactive outreach' }
            ]
          },
          {
            title: 'Loyalty Program',
            fields: [
              { name: 'loyalty_program', label: 'Has Loyalty Program', type: 'checkbox' },
              { name: 'reward_structure', label: 'Reward Structure', type: 'json',
                help: 'Points, tiers, and rewards structure' },
              { name: 'referral_incentives', label: 'Referral Incentives', type: 'text',
                help: 'Incentives for customer referrals' }
            ]
          }
        ]
      },
      advocacy: {
        sections: [
          {
            title: 'Advocacy Programs',
            fields: [
              { name: 'advocacy_type', label: 'Advocacy Type', type: 'select', required: true,
                options: ['referral_program', 'case_study', 'testimonial', 'review_campaign', 'user_generated_content', 'brand_ambassador'] },
              { name: 'program_details', label: 'Program Details', type: 'richtext', required: true },
              { name: 'participation_requirements', label: 'Participation Requirements', type: 'textarea', rows: 3 }
            ]
          },
          {
            title: 'Incentives & Rewards',
            fields: [
              { name: 'referral_reward', label: 'Referral Reward', type: 'text',
                help: 'Reward for successful referrals' },
              { name: 'advocate_recognition', label: 'Advocate Recognition', type: 'multiselect',
                options: ['public_recognition', 'exclusive_access', 'swag', 'monetary_reward', 'certificate'] },
              { name: 'social_sharing_incentives', label: 'Social Sharing Incentives', type: 'text' }
            ]
          },
          {
            title: 'Content Creation',
            fields: [
              { name: 'content_requests', label: 'Content Requests', type: 'multiselect',
                options: ['testimonials', 'case_studies', 'reviews', 'social_posts', 'videos', 'blog_posts'] },
              { name: 'content_guidelines', label: 'Content Guidelines', type: 'richtext',
                help: 'Guidelines for user-generated content' },
              { name: 'approval_process', label: 'Content Approval Process', type: 'textarea', rows: 2 }
            ]
          }
        ]
      },
      default: {
        sections: [
          {
            title: 'Basic Configuration',
            fields: [
              { name: 'stage_objective', label: 'Stage Objective', type: 'textarea', required: true, rows: 2,
                help: 'What should this stage accomplish?' },
              { name: 'success_criteria', label: 'Success Criteria', type: 'textarea', required: true, rows: 2,
                help: 'How will you measure success for this stage?' }
            ]
          }
        ]
      }
    }
  }

  // Get field value from current stage data
  getFieldValue(fieldName) {
    if (!this.currentStage.configuration) return ''
    return this.currentStage.configuration[fieldName] || ''
  }

  // Populate form with existing stage data
  populateForm() {
    if (this.hasStageNameInputTarget) {
      this.stageNameInputTarget.value = this.currentStage.name || ''
    }
    if (this.hasStageDescriptionInputTarget) {
      this.stageDescriptionInputTarget.value = this.currentStage.description || ''
    }
    if (this.hasStageDurationInputTarget) {
      this.stageDurationInputTarget.value = this.currentStage.duration_days || ''
    }
  }

  // Handle field input for real-time validation
  handleFieldInput(event) {
    const field = event.target
    this.clearFieldError(field)
    
    // Perform field-specific validation
    this.validateField(field)
  }

  // Handle field change
  handleFieldChange(event) {
    const field = event.target
    this.validateField(field)
  }

  // Validate individual field
  validateField(field) {
    const fieldName = field.name
    const fieldType = field.dataset.fieldType
    const value = field.value
    let isValid = true
    let errorMessage = ''

    // Required field validation
    if (field.required && !value.trim()) {
      isValid = false
      errorMessage = 'This field is required'
    }

    // Type-specific validation
    if (isValid && value) {
      switch (fieldType) {
        case 'email':
          if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
            isValid = false
            errorMessage = 'Please enter a valid email address'
          }
          break
        case 'url':
          if (!/^https?:\/\/.+/.test(value)) {
            isValid = false
            errorMessage = 'Please enter a valid URL starting with http:// or https://'
          }
          break
        case 'number':
          if (isNaN(value)) {
            isValid = false
            errorMessage = 'Please enter a valid number'
          } else {
            const num = parseFloat(value)
            if (field.min !== undefined && num < parseFloat(field.min)) {
              isValid = false
              errorMessage = `Value must be at least ${field.min}`
            }
            if (field.max !== undefined && num > parseFloat(field.max)) {
              isValid = false
              errorMessage = `Value must be at most ${field.max}`
            }
          }
          break
        case 'json':
          try {
            JSON.parse(value)
          } catch (error) {
            isValid = false
            errorMessage = 'Invalid JSON format'
          }
          break
      }
    }

    // Show/hide error
    if (!isValid) {
      this.setFieldError(field, errorMessage)
    } else {
      this.clearFieldError(field)
    }

    return isValid
  }

  // Set field error
  setFieldError(field, message) {
    const errorElement = field.closest('.form-field').querySelector('.field-error')
    if (errorElement) {
      errorElement.textContent = message
      errorElement.classList.remove('hidden')
    }
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
  }

  // Clear field error
  clearFieldError(field) {
    const errorElement = field.closest('.form-field').querySelector('.field-error')
    if (errorElement) {
      errorElement.classList.add('hidden')
    }
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
  }

  // Clear all errors
  clearErrors() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = ''
    }
    
    this.element.querySelectorAll('.field-error').forEach(error => {
      error.classList.add('hidden')
    })
    
    this.element.querySelectorAll('.border-red-300').forEach(field => {
      field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
      field.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500')
    })
  }

  // Validate entire form
  validateForm() {
    let isValid = true
    const fields = this.formTarget.querySelectorAll('input, textarea, select')
    
    fields.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })
    
    return isValid
  }

  // Handle form submission
  handleFormSubmit(event) {
    event.preventDefault()
    
    if (!this.validateForm()) {
      return
    }
    
    const formData = this.getFormData()
    this.saveStageConfiguration(formData)
  }

  // Get form data
  getFormData() {
    const formData = new FormData(this.formTarget)
    const data = {}
    
    // Convert FormData to regular object
    for (let [key, value] of formData.entries()) {
      if (key.endsWith('[]')) {
        // Handle multi-select fields
        const cleanKey = key.slice(0, -2)
        if (!data[cleanKey]) data[cleanKey] = []
        data[cleanKey].push(value)
      } else {
        data[key] = value
      }
    }
    
    // Handle JSON fields
    this.element.querySelectorAll('[data-field-type="json"]').forEach(field => {
      try {
        data[field.name] = JSON.parse(field.value || '{}')
      } catch (error) {
        data[field.name] = field.value
      }
    })
    
    return data
  }

  // Save stage configuration
  async saveStageConfiguration(formData) {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = true
      this.saveButtonTarget.textContent = 'Saving...'
    }

    try {
      // Update current stage with form data
      this.currentStage.name = formData.name || this.currentStage.name
      this.currentStage.description = formData.description || this.currentStage.description
      this.currentStage.duration_days = parseInt(formData.duration_days) || this.currentStage.duration_days
      
      // Store dynamic field data in configuration
      this.currentStage.configuration = this.currentStage.configuration || {}
      Object.keys(formData).forEach(key => {
        if (!['name', 'description', 'duration_days'].includes(key)) {
          this.currentStage.configuration[key] = formData[key]
        }
      })

      // Dispatch event to notify parent component
      this.dispatch('stageConfigSaved', {
        detail: { 
          stage: this.currentStage,
          formData: formData
        }
      })

      // Show success message
      this.showNotification('Stage configuration saved successfully!', 'success')

    } catch (error) {
      console.error('Error saving stage configuration:', error)
      this.showNotification('Failed to save stage configuration. Please try again.', 'error')
    } finally {
      if (this.hasSaveButtonTarget) {
        this.saveButtonTarget.disabled = false
        this.saveButtonTarget.textContent = 'Save Changes'
      }
    }
  }

  // Show notification
  showNotification(message, type = 'info') {
    // Dispatch event for parent component to handle notifications
    this.dispatch('notification', {
      detail: { message, type }
    })
  }

  // Update stage data from external source
  updateStageData(stageData) {
    this.currentStage = { ...stageData }
    this.populateForm()
    this.updateDynamicFields()
  }

  // Cancel form editing
  cancel() {
    this.dispatch('configCancelled')
  }
}