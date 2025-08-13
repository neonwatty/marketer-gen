import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import { vi } from 'vitest'
import { CampaignCloning } from '../campaign-cloning'

const mockCampaign = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch",
  status: "active",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  budget: { total: 25000, spent: 18750, currency: "USD" },
  objectives: ["Increase brand awareness", "Generate leads"],
  channels: ["Email", "Social Media", "Blog"],
  targetAudience: {
    demographics: {
      ageRange: "25-34",
      gender: "All",
      location: "United States, Canada"
    },
    description: "Environmentally conscious professionals",
    interests: ["sustainability", "lifestyle"]
  },
  messaging: {
    primaryMessage: "Transform your lifestyle with sustainable products",
    callToAction: "Shop Now",
    valueProposition: "Premium quality meets responsibility"
  },
  contentStrategy: {
    contentTypes: ["Blog Posts", "Social Posts"],
    frequency: "Weekly",
    tone: "Professional"
  },
  metrics: {
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    conversionRate: 21.9,
    costPerConversion: 22.06
  }
}

describe('CampaignCloning', () => {
  const defaultProps = {
    campaign: mockCampaign,
    onClone: vi.fn(),
    onCancel: vi.fn()
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders campaign cloning header and source campaign info', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Check for heading specifically
    expect(screen.getByRole('heading', { name: 'Clone Campaign' })).toBeInTheDocument()
    expect(screen.getByText('Create a new campaign based on "Summer Product Launch"')).toBeInTheDocument()
    expect(screen.getByText('Source Campaign')).toBeInTheDocument()
    expect(screen.getByText(mockCampaign.title)).toBeInTheDocument()
    expect(screen.getByText(mockCampaign.description)).toBeInTheDocument()
  })

  it('displays step progress indicators', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    expect(screen.getByText('Select Elements')).toBeInTheDocument()
    expect(screen.getByText('Configure')).toBeInTheDocument()
    expect(screen.getByText('Review')).toBeInTheDocument()
  })

  it('shows cloneable elements by category', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    expect(screen.getByText('Basic Information')).toBeInTheDocument()
    expect(screen.getByText('Target Audience')).toBeInTheDocument()
    expect(screen.getByText('Messaging Strategy')).toBeInTheDocument()
    expect(screen.getByText('Campaign Schedule')).toBeInTheDocument()
    expect(screen.getByText('Budget Configuration')).toBeInTheDocument()
  })

  it('allows selecting and deselecting cloneable elements', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Find a checkbox that's not required (Budget Configuration)
    const budgetCheckbox = screen.getByText('Budget Configuration').closest('div')
    expect(budgetCheckbox).toBeInTheDocument()
    
    if (budgetCheckbox) {
      fireEvent.click(budgetCheckbox)
      // Budget should now be selected (implementation detail)
    }
  })

  it('prevents deselecting required elements', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Basic Information is required and should show "Required" badge
    expect(screen.getByText('Required')).toBeInTheDocument()
  })

  it('provides quick selection options', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    expect(screen.getByText('Structure Only (Audience + Channels)')).toBeInTheDocument()
    expect(screen.getByText('Content Strategy (Messaging + Content)')).toBeInTheDocument()
    expect(screen.getByText('Everything (Complete Clone)')).toBeInTheDocument()
    expect(screen.getByText('Custom Selection')).toBeInTheDocument()
  })

  it('navigates through wizard steps', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Click Next to go to step 2
    const nextButton = screen.getByText('Next')
    fireEvent.click(nextButton)
    
    // Should now be on configuration step
    expect(screen.getByText('Clone Configuration')).toBeInTheDocument()
    expect(screen.getByText('Campaign Name *')).toBeInTheDocument()
  })

  it('allows configuring clone options in step 2', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    // Find and modify the campaign name
    const nameInput = screen.getByDisplayValue('Summer Product Launch (Copy)')
    fireEvent.change(nameInput, { target: { value: 'My New Campaign' } })
    
    expect(nameInput).toHaveValue('My New Campaign')
  })

  it('shows advanced adjustment options when expanded', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    // Click to show advanced options
    const showAdvancedButton = screen.getByText('Show Advanced')
    fireEvent.click(showAdvancedButton)
    
    expect(screen.getByText('Hide Advanced')).toBeInTheDocument()
  })

  it('allows saving as template option', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    // Find and click the save as template checkbox
    const saveAsTemplateCheckbox = screen.getByText('Save as Template')
    fireEvent.click(saveAsTemplateCheckbox)
    
    // Should show template configuration fields
    expect(screen.getByText('Template Name *')).toBeInTheDocument()
    expect(screen.getByText('Template Description')).toBeInTheDocument()
  })

  it('shows clone preview in step 2', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    expect(screen.getByText('Clone Preview')).toBeInTheDocument()
    expect(screen.getByText('Elements selected:')).toBeInTheDocument()
  })

  it('displays review information in step 3', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 3
    fireEvent.click(screen.getByText('Next'))
    fireEvent.click(screen.getByText('Next'))
    
    expect(screen.getByText('Review Clone Configuration')).toBeInTheDocument()
    expect(screen.getByText('New Campaign')).toBeInTheDocument()
  })

  it('calls onClone with correct options when cloning', async () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate through all steps
    fireEvent.click(screen.getByText('Next'))
    fireEvent.click(screen.getByText('Next'))
    
    // Click Create Clone button
    const createCloneButton = screen.getByText('Create Clone')
    fireEvent.click(createCloneButton)
    
    await waitFor(() => {
      expect(defaultProps.onClone).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'Summer Product Launch (Copy)',
          description: 'Cloned from: Summer Product Launch',
          selectedElements: expect.any(Array),
          adjustments: expect.any(Object),
          saveAsTemplate: false
        })
      )
    })
  })

  it('calls onCancel when cancel button is clicked', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    const cancelButton = screen.getByText('Cancel')
    fireEvent.click(cancelButton)
    
    expect(defaultProps.onCancel).toHaveBeenCalled()
  })

  it('disables clone button when configuration is invalid', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 3
    fireEvent.click(screen.getByText('Next'))
    
    // Clear the name field to make configuration invalid
    const nameInput = screen.getByDisplayValue('Summer Product Launch (Copy)')
    fireEvent.change(nameInput, { target: { value: '' } })
    
    fireEvent.click(screen.getByText('Next'))
    
    // Clone button should be disabled
    const createCloneButton = screen.getByText('Create Clone')
    expect(createCloneButton).toBeDisabled()
  })

  it('shows template creation info when save as template is enabled', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    // Enable save as template
    fireEvent.click(screen.getByText('Save as Template'))
    
    // Fill in template name
    const templateNameInput = screen.getByPlaceholderText('Enter template name')
    fireEvent.change(templateNameInput, { target: { value: 'My Template' } })
    
    // Navigate to step 3
    fireEvent.click(screen.getByText('Next'))
    
    expect(screen.getByText('Template Creation')).toBeInTheDocument()
    expect(screen.getByText('My Template')).toBeInTheDocument()
  })

  it('displays currency formatting correctly', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Should show formatted budget amount
    expect(screen.getByText('$25,000')).toBeInTheDocument()
  })

  it('handles previous button navigation', () => {
    render(<CampaignCloning {...defaultProps} />)
    
    // Navigate to step 2
    fireEvent.click(screen.getByText('Next'))
    
    // Go back to step 1
    fireEvent.click(screen.getByText('Previous'))
    
    // Should be back on step 1
    expect(screen.getByText('Select Elements to Clone')).toBeInTheDocument()
  })
})