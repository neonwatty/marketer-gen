import React, { useState, useEffect, useMemo } from 'react'

interface TemplateVariable {
  name: string
  type: 'text' | 'number' | 'date' | 'select' | 'boolean'
  label: string
  placeholder?: string
  required?: boolean
  defaultValue?: any
  options?: string[] // for select type
  description?: string
}

interface ContentTemplate {
  id: string
  name: string
  description: string
  category: string
  content: string
  variables: TemplateVariable[]
  thumbnail?: string
  author: string
  isPublic: boolean
  isFavorite?: boolean
  usageCount: number
  tags: string[]
  createdAt: Date
  updatedAt: Date
  brandCompliant?: boolean
}

interface ContentTemplatesProps {
  onSelectTemplate?: (template: ContentTemplate, variables: Record<string, any>) => void
  onCreateTemplate?: (template: Omit<ContentTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount'>) => void
  allowCustomTemplates?: boolean
  showFavorites?: boolean
  brandColors?: string[]
  className?: string
}

export const ContentTemplates: React.FC<ContentTemplatesProps> = ({
  onSelectTemplate,
  onCreateTemplate: _onCreateTemplate,
  allowCustomTemplates = true,
  showFavorites = true,
  brandColors: _brandColors = [],
  className = ''
}) => {
  const [templates, setTemplates] = useState<ContentTemplate[]>([])
  const [filteredTemplates, setFilteredTemplates] = useState<ContentTemplate[]>([])
  const [selectedTemplate, setSelectedTemplate] = useState<ContentTemplate | null>(null)
  const [templateVariables, setTemplateVariables] = useState<Record<string, any>>({})
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [showOnlyFavorites, setShowOnlyFavorites] = useState(false)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [viewMode, _setViewMode] = useState<'grid' | 'list'>('grid')

  // Mock templates data
  useEffect(() => {
    const mockTemplates: ContentTemplate[] = [
      {
        id: '1',
        name: 'Social Media Post',
        description: 'Engaging social media post template with call-to-action',
        category: 'Social Media',
        content: `🚀 Exciting news! {{announcement}}

{{description}}

Ready to {{action}}? 

{{call_to_action}}

#{{hashtag}} #marketing`,
        variables: [
          {
            name: 'announcement',
            type: 'text',
            label: 'Announcement',
            placeholder: 'We\'re launching something amazing...',
            required: true
          },
          {
            name: 'description',
            type: 'text',
            label: 'Description',
            placeholder: 'Brief description of your announcement',
            required: true
          },
          {
            name: 'action',
            type: 'text',
            label: 'Action Verb',
            placeholder: 'learn more, get started, try it out',
            defaultValue: 'learn more'
          },
          {
            name: 'call_to_action',
            type: 'text',
            label: 'Call to Action',
            placeholder: 'Visit our website, Sign up today, etc.',
            required: true
          },
          {
            name: 'hashtag',
            type: 'text',
            label: 'Primary Hashtag',
            placeholder: 'yourcompany'
          }
        ],
        thumbnail: '📱',
        author: 'System',
        isPublic: true,
        isFavorite: true,
        usageCount: 145,
        tags: ['social', 'announcement', 'engagement'],
        createdAt: new Date('2024-01-01'),
        updatedAt: new Date('2024-01-15'),
        brandCompliant: true
      },
      {
        id: '2',
        name: 'Email Newsletter',
        description: 'Professional email newsletter template',
        category: 'Email',
        content: `Subject: {{subject}}

Hi {{recipient_name}},

{{opening_line}}

{{main_content}}

{{closing_line}}

Best regards,
{{sender_name}}
{{company_name}}

{{footer_text}}`,
        variables: [
          {
            name: 'subject',
            type: 'text',
            label: 'Email Subject',
            placeholder: 'Your weekly update',
            required: true
          },
          {
            name: 'recipient_name',
            type: 'text',
            label: 'Recipient Name',
            placeholder: 'John',
            defaultValue: 'there'
          },
          {
            name: 'opening_line',
            type: 'text',
            label: 'Opening Line',
            placeholder: 'Hope you\'re having a great week!',
            required: true
          },
          {
            name: 'main_content',
            type: 'text',
            label: 'Main Content',
            placeholder: 'Your main newsletter content here...',
            required: true
          },
          {
            name: 'closing_line',
            type: 'text',
            label: 'Closing Line',
            placeholder: 'Thanks for being an amazing subscriber!',
            required: true
          },
          {
            name: 'sender_name',
            type: 'text',
            label: 'Sender Name',
            placeholder: 'Jane Smith',
            required: true
          },
          {
            name: 'company_name',
            type: 'text',
            label: 'Company Name',
            placeholder: 'Your Company',
            required: true
          },
          {
            name: 'footer_text',
            type: 'text',
            label: 'Footer Text',
            placeholder: 'Unsubscribe | Privacy Policy',
            defaultValue: 'You received this email because you subscribed to our newsletter.'
          }
        ],
        thumbnail: '📧',
        author: 'Marketing Team',
        isPublic: true,
        isFavorite: false,
        usageCount: 89,
        tags: ['email', 'newsletter', 'professional'],
        createdAt: new Date('2024-01-05'),
        updatedAt: new Date('2024-01-20'),
        brandCompliant: true
      },
      {
        id: '3',
        name: 'Blog Post Outline',
        description: 'Structured blog post template with SEO considerations',
        category: 'Blog',
        content: `# {{title}}

## Introduction
{{introduction}}

## {{section_1_title}}
{{section_1_content}}

## {{section_2_title}}
{{section_2_content}}

## {{section_3_title}}
{{section_3_content}}

## Conclusion
{{conclusion}}

---

**Tags:** {{tags}}
**Word Count:** Approximately {{word_count}} words
**SEO Focus:** {{seo_keywords}}`,
        variables: [
          {
            name: 'title',
            type: 'text',
            label: 'Blog Title',
            placeholder: '10 Tips for Better Marketing',
            required: true
          },
          {
            name: 'introduction',
            type: 'text',
            label: 'Introduction',
            placeholder: 'Hook your readers with an engaging introduction...',
            required: true
          },
          {
            name: 'section_1_title',
            type: 'text',
            label: 'Section 1 Title',
            placeholder: 'Understanding Your Audience',
            required: true
          },
          {
            name: 'section_1_content',
            type: 'text',
            label: 'Section 1 Content',
            placeholder: 'Content for first section...',
            required: true
          },
          {
            name: 'section_2_title',
            type: 'text',
            label: 'Section 2 Title',
            placeholder: 'Creating Compelling Content',
            required: true
          },
          {
            name: 'section_2_content',
            type: 'text',
            label: 'Section 2 Content',
            placeholder: 'Content for second section...',
            required: true
          },
          {
            name: 'section_3_title',
            type: 'text',
            label: 'Section 3 Title',
            placeholder: 'Measuring Success',
            required: true
          },
          {
            name: 'section_3_content',
            type: 'text',
            label: 'Section 3 Content',
            placeholder: 'Content for third section...',
            required: true
          },
          {
            name: 'conclusion',
            type: 'text',
            label: 'Conclusion',
            placeholder: 'Wrap up with key takeaways and next steps...',
            required: true
          },
          {
            name: 'tags',
            type: 'text',
            label: 'Tags',
            placeholder: 'marketing, tips, strategy',
            required: true
          },
          {
            name: 'word_count',
            type: 'number',
            label: 'Target Word Count',
            defaultValue: 1500
          },
          {
            name: 'seo_keywords',
            type: 'text',
            label: 'SEO Keywords',
            placeholder: 'marketing tips, digital marketing',
            required: true
          }
        ],
        thumbnail: '📝',
        author: 'Content Team',
        isPublic: true,
        isFavorite: true,
        usageCount: 67,
        tags: ['blog', 'seo', 'content'],
        createdAt: new Date('2024-01-10'),
        updatedAt: new Date('2024-01-25'),
        brandCompliant: true
      },
      {
        id: '4',
        name: 'Product Launch Announcement',
        description: 'Comprehensive product launch template',
        category: 'Product',
        content: `🎉 Introducing {{product_name}}!

After {{development_time}} of development, we're thrilled to announce the launch of {{product_name}} - {{product_tagline}}.

**What makes {{product_name}} special?**
{{key_features}}

**Who is it for?**
{{target_audience}}

**Pricing:**
{{pricing_info}}

**Availability:**
{{availability_info}}

{{launch_offer}}

Ready to experience {{product_name}}? {{call_to_action}}

Questions? Reply to this message or contact us at {{contact_info}}.

#{{company_hashtag}} #{{product_hashtag}} #launch`,
        variables: [
          {
            name: 'product_name',
            type: 'text',
            label: 'Product Name',
            placeholder: 'Amazing Product',
            required: true
          },
          {
            name: 'development_time',
            type: 'text',
            label: 'Development Time',
            placeholder: '6 months',
            required: true
          },
          {
            name: 'product_tagline',
            type: 'text',
            label: 'Product Tagline',
            placeholder: 'The tool that changes everything',
            required: true
          },
          {
            name: 'key_features',
            type: 'text',
            label: 'Key Features',
            placeholder: '• Feature 1\n• Feature 2\n• Feature 3',
            required: true
          },
          {
            name: 'target_audience',
            type: 'text',
            label: 'Target Audience',
            placeholder: 'Small business owners and entrepreneurs',
            required: true
          },
          {
            name: 'pricing_info',
            type: 'text',
            label: 'Pricing Information',
            placeholder: 'Starting at $99/month',
            required: true
          },
          {
            name: 'availability_info',
            type: 'text',
            label: 'Availability',
            placeholder: 'Available now worldwide',
            required: true
          },
          {
            name: 'launch_offer',
            type: 'text',
            label: 'Launch Offer',
            placeholder: '🚀 Early bird special: 50% off for the first 100 customers!',
            defaultValue: ''
          },
          {
            name: 'call_to_action',
            type: 'text',
            label: 'Call to Action',
            placeholder: 'Get started at example.com',
            required: true
          },
          {
            name: 'contact_info',
            type: 'text',
            label: 'Contact Information',
            placeholder: 'support@example.com',
            required: true
          },
          {
            name: 'company_hashtag',
            type: 'text',
            label: 'Company Hashtag',
            placeholder: 'yourcompany',
            required: true
          },
          {
            name: 'product_hashtag',
            type: 'text',
            label: 'Product Hashtag',
            placeholder: 'amazingproduct',
            required: true
          }
        ],
        thumbnail: '🚀',
        author: 'Product Team',
        isPublic: true,
        isFavorite: false,
        usageCount: 34,
        tags: ['product', 'launch', 'announcement'],
        createdAt: new Date('2024-01-20'),
        updatedAt: new Date('2024-01-30'),
        brandCompliant: true
      }
    ]
    setTemplates(mockTemplates)
  }, [])

  // Get unique categories
  const categories = useMemo(() => {
    const cats = templates.map(t => t.category)
    return ['all', ...Array.from(new Set(cats))]
  }, [templates])

  // Filter templates
  useEffect(() => {
    let filtered = templates

    if (selectedCategory !== 'all') {
      filtered = filtered.filter(t => t.category === selectedCategory)
    }

    if (showOnlyFavorites) {
      filtered = filtered.filter(t => t.isFavorite)
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(t =>
        t.name.toLowerCase().includes(query) ||
        t.description.toLowerCase().includes(query) ||
        t.tags.some(tag => tag.toLowerCase().includes(query))
      )
    }

    setFilteredTemplates(filtered)
  }, [templates, selectedCategory, showOnlyFavorites, searchQuery])

  const toggleFavorite = (templateId: string) => {
    setTemplates(prev => prev.map(t => 
      t.id === templateId ? { ...t, isFavorite: !t.isFavorite } : t
    ))
  }

  const previewTemplate = (template: ContentTemplate) => {
    let content = template.content
    
    // Replace variables with example values or placeholders
    template.variables.forEach(variable => {
      const placeholder = templateVariables[variable.name] || 
        variable.defaultValue || 
        variable.placeholder || 
        `{{${variable.name}}}`
      
      const regex = new RegExp(`{{${variable.name}}}`, 'g')
      content = content.replace(regex, String(placeholder))
    })

    return content
  }

  const handleTemplateSelect = (template: ContentTemplate) => {
    setSelectedTemplate(template)
    
    // Initialize variables with default values
    const initialVariables: Record<string, any> = {}
    template.variables.forEach(variable => {
      if (variable.defaultValue !== undefined) {
        initialVariables[variable.name] = variable.defaultValue
      }
    })
    setTemplateVariables(initialVariables)
  }

  const handleVariableChange = (variableName: string, value: any) => {
    setTemplateVariables(prev => ({
      ...prev,
      [variableName]: value
    }))
  }

  const handleUseTemplate = () => {
    if (!selectedTemplate) {return}

    // Validate required variables
    const missingRequired = selectedTemplate.variables
      .filter(v => v.required && !templateVariables[v.name])
      .map(v => v.label)

    if (missingRequired.length > 0) {
      alert(`Please fill in required fields: ${missingRequired.join(', ')}`)
      return
    }

    onSelectTemplate?.(selectedTemplate, templateVariables)
    setSelectedTemplate(null)
    setTemplateVariables({})
  }

  const renderVariableInput = (variable: TemplateVariable) => {
    const value = templateVariables[variable.name] || ''

    switch (variable.type) {
      case 'select':
        return (
          <select
            value={value}
            onChange={(e) => handleVariableChange(variable.name, e.target.value)}
            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            required={variable.required}
          >
            <option value="">Select...</option>
            {variable.options?.map(option => (
              <option key={option} value={option}>{option}</option>
            ))}
          </select>
        )
      
      case 'boolean':
        return (
          <input
            type="checkbox"
            checked={value}
            onChange={(e) => handleVariableChange(variable.name, e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
        )
      
      case 'number':
        return (
          <input
            type="number"
            value={value}
            onChange={(e) => handleVariableChange(variable.name, parseFloat(e.target.value) || 0)}
            placeholder={variable.placeholder}
            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            required={variable.required}
          />
        )
      
      case 'date':
        return (
          <input
            type="date"
            value={value}
            onChange={(e) => handleVariableChange(variable.name, e.target.value)}
            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            required={variable.required}
          />
        )
      
      default:
        return (
          <textarea
            value={value}
            onChange={(e) => handleVariableChange(variable.name, e.target.value)}
            placeholder={variable.placeholder}
            rows={variable.name.includes('content') ? 4 : 2}
            className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            required={variable.required}
          />
        )
    }
  }

  const renderTemplateCard = (template: ContentTemplate) => (
    <div
      key={template.id}
      className="bg-white border border-gray-200 rounded-lg hover:shadow-md transition-shadow duration-200 cursor-pointer"
      onClick={() => handleTemplateSelect(template)}
    >
      <div className="p-4">
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center space-x-3">
            <div className="text-2xl">{template.thumbnail}</div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">{template.name}</h3>
              <p className="text-sm text-gray-600">{template.description}</p>
            </div>
          </div>
          
          <button
            onClick={(e) => {
              e.stopPropagation()
              toggleFavorite(template.id)
            }}
            className="text-gray-400 hover:text-red-500 transition-colors"
          >
            {template.isFavorite ? '❤️' : '🤍'}
          </button>
        </div>

        <div className="flex items-center justify-between text-sm text-gray-500 mb-3">
          <span className="bg-gray-100 px-2 py-1 rounded">{template.category}</span>
          <span>{template.usageCount} uses</span>
        </div>

        <div className="flex flex-wrap gap-1 mb-3">
          {template.tags.map(tag => (
            <span key={tag} className="inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800">
              {tag}
            </span>
          ))}
        </div>

        <div className="flex items-center justify-between text-xs text-gray-400">
          <span>By {template.author}</span>
          {template.brandCompliant && (
            <span className="text-green-600 flex items-center">
              <svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              Brand Compliant
            </span>
          )}
        </div>
      </div>
    </div>
  )

  return (
    <div className={`content-templates ${className}`}>
      {!selectedTemplate ? (
        <>
          {/* Header */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-3 sm:space-y-0 mb-6">
            <h2 className="text-2xl font-bold text-gray-900">Content Templates</h2>
            
            {allowCustomTemplates && (
              <button
                onClick={() => setShowCreateModal(true)}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                Create Template
              </button>
            )}
          </div>

          {/* Filters */}
          <div className="flex flex-col sm:flex-row sm:items-center space-y-3 sm:space-y-0 sm:space-x-4 mb-6">
            {/* Search */}
            <div className="flex-1 relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <input
                type="text"
                placeholder="Search templates..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              />
            </div>

            {/* Category Filter */}
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="block pl-3 pr-10 py-2 text-base border border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
            >
              {categories.map(category => (
                <option key={category} value={category}>
                  {category === 'all' ? 'All Categories' : category}
                </option>
              ))}
            </select>

            {/* Favorites Toggle */}
            {showFavorites && (
              <label className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={showOnlyFavorites}
                  onChange={(e) => setShowOnlyFavorites(e.target.checked)}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <span className="text-sm text-gray-700">Favorites only</span>
              </label>
            )}
          </div>

          {/* Templates Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredTemplates.map(renderTemplateCard)}
          </div>

          {filteredTemplates.length === 0 && (
            <div className="text-center py-12">
              <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <h3 className="mt-2 text-sm font-medium text-gray-900">No templates found</h3>
              <p className="mt-1 text-sm text-gray-500">
                Try adjusting your search or create a new template
              </p>
            </div>
          )}
        </>
      ) : (
        /* Template Editor */
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Variables Form */}
          <div className="space-y-6">
            <div className="flex items-center space-x-4">
              <button
                onClick={() => setSelectedTemplate(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <div>
                <h3 className="text-xl font-semibold text-gray-900">{selectedTemplate.name}</h3>
                <p className="text-sm text-gray-600">{selectedTemplate.description}</p>
              </div>
            </div>

            <div className="space-y-4">
              {selectedTemplate.variables.map(variable => (
                <div key={variable.name}>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    {variable.label}
                    {variable.required && <span className="text-red-500 ml-1">*</span>}
                  </label>
                  {renderVariableInput(variable)}
                  {variable.description && (
                    <p className="mt-1 text-xs text-gray-500">{variable.description}</p>
                  )}
                </div>
              ))}
            </div>

            <div className="flex space-x-3">
              <button
                onClick={handleUseTemplate}
                className="flex-1 inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Use Template
              </button>
              <button
                onClick={() => setSelectedTemplate(null)}
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Cancel
              </button>
            </div>
          </div>

          {/* Preview */}
          <div className="space-y-4">
            <h4 className="text-lg font-medium text-gray-900">Preview</h4>
            <div className="border border-gray-300 rounded-lg p-4 bg-gray-50 h-96 overflow-auto">
              <pre className="whitespace-pre-wrap text-sm font-mono">
                {previewTemplate(selectedTemplate)}
              </pre>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default ContentTemplates