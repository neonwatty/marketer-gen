import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import '@testing-library/jest-dom'
import { vi } from 'vitest'
import { StakeholderPresentation } from '../stakeholder-presentation'

// Mock the fullscreen API
Object.defineProperty(document, 'fullscreenElement', {
  writable: true,
  value: null,
})

Object.defineProperty(document.documentElement, 'requestFullscreen', {
  writable: true,
  value: vi.fn(),
})

Object.defineProperty(document, 'exitFullscreen', {
  writable: true,
  value: vi.fn(),
})

const mockCampaign = {
  id: "1",
  title: "Summer Product Launch",
  description: "Multi-channel campaign for new product line launch targeting millennials with focus on sustainability",
  status: "active",
  startDate: "2024-02-01",
  endDate: "2024-04-30",
  budget: {
    total: 25000,
    spent: 18750,
    currency: "USD"
  },
  objectives: ["brand-awareness", "lead-generation", "sales-conversion"],
  channels: ["Email", "Social Media", "Blog", "Display Ads"],
  targetAudience: {
    demographics: {
      ageRange: "25-34",
      gender: "all",
      location: "United States, Canada"
    },
    description: "Environmentally conscious millennials interested in sustainable living"
  },
  messaging: {
    primaryMessage: "Discover sustainable living with our eco-friendly product line",
    callToAction: "Shop Sustainable",
    valueProposition: "Premium quality meets environmental responsibility"
  },
  metrics: {
    progress: 75,
    contentPieces: 12,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850,
    clickThroughRate: 3.1,
    costPerConversion: 22.06
  },
  journey: {
    stages: [
      {
        id: "awareness",
        name: "Awareness",
        description: "Brand introduction and problem recognition",
        status: "completed",
        channels: ["Blog", "Social Media", "Display Ads"],
        contentCount: 8,
        metrics: { impressions: 75000, engagement: 3.8 }
      },
      {
        id: "consideration", 
        name: "Consideration",
        description: "Product evaluation and comparison",
        status: "active",
        channels: ["Email", "Social Media", "Blog"],
        contentCount: 6,
        metrics: { impressions: 40000, engagement: 5.2 }
      },
      {
        id: "conversion",
        name: "Conversion", 
        description: "Purchase decision and action",
        status: "active",
        channels: ["Email", "Landing Pages"],
        contentCount: 4,
        metrics: { impressions: 10000, engagement: 6.8 }
      },
      {
        id: "retention",
        name: "Retention",
        description: "Post-purchase engagement and loyalty", 
        status: "pending",
        channels: ["Email", "Social Media"],
        contentCount: 0,
        metrics: { impressions: 0, engagement: 0 }
      }
    ]
  }
}

describe('StakeholderPresentation', () => {
  beforeEach(() => {
    // Reset mocks
    vi.clearAllMocks()
  })

  it('renders presentation header and controls', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    expect(screen.getByText('Stakeholder Presentation')).toBeInTheDocument()
    expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
    expect(screen.getByText('Export PDF')).toBeInTheDocument()
    expect(screen.getByText('Export PowerPoint')).toBeInTheDocument()
    expect(screen.getByText('Print')).toBeInTheDocument()
    expect(screen.getByText('Present')).toBeInTheDocument()
  })

  it('displays the first slide (overview) by default', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
    expect(screen.getByText('Multi-channel campaign for new product line launch targeting millennials with focus on sustainability')).toBeInTheDocument()
    expect(screen.getByText('$18,750')).toBeInTheDocument()
    expect(screen.getByText('125,000')).toBeInTheDocument()
    expect(screen.getByText('4.2%')).toBeInTheDocument()
    expect(screen.getByText('850')).toBeInTheDocument()
  })

  it('navigates between slides using navigation buttons', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    const nextButton = screen.getByText('Next')
    const prevButton = screen.getByText('Previous')
    
    // Should start with Previous disabled
    expect(prevButton).toBeDisabled()
    expect(nextButton).not.toBeDisabled()
    
    // Navigate to next slide
    fireEvent.click(nextButton)
    
    // Should now show metrics slide
    expect(screen.getByText('Performance Metrics')).toBeInTheDocument()
    expect(screen.getByText('Key performance indicators and campaign progress')).toBeInTheDocument()
    
    // Previous should now be enabled
    expect(prevButton).not.toBeDisabled()
    
    // Go back to first slide
    fireEvent.click(prevButton)
    expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
  })

  it('navigates slides using slide indicator dots', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    const slideDots = screen.getAllByRole('button').filter(button => 
      button.className.includes('rounded-full')
    )
    
    expect(slideDots).toHaveLength(6) // 6 slides total
    
    // Click on third slide dot (journey slide)
    fireEvent.click(slideDots[2])
    expect(screen.getByText('Customer Journey')).toBeInTheDocument()
    expect(screen.getByText('Multi-stage campaign strategy and performance')).toBeInTheDocument()
  })

  it('handles fullscreen presentation mode', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    const presentButton = screen.getByText('Present')
    fireEvent.click(presentButton)
    
    expect(document.documentElement.requestFullscreen).toHaveBeenCalled()
  })

  it('displays campaign overview slide with correct data', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Check campaign status badge
    expect(screen.getByText('Active')).toBeInTheDocument()
    
    // Check budget information
    expect(screen.getByText('$18,750')).toBeInTheDocument()
    expect(screen.getByText('of $25,000 spent')).toBeInTheDocument()
    
    // Check metrics
    expect(screen.getByText('125,000')).toBeInTheDocument()
    expect(screen.getByText('Total Impressions')).toBeInTheDocument()
    expect(screen.getByText('4.2%')).toBeInTheDocument()
    expect(screen.getByText('Engagement Rate')).toBeInTheDocument()
    expect(screen.getByText('850')).toBeInTheDocument()
    expect(screen.getByText('Conversions')).toBeInTheDocument()
    
    // Check date range
    expect(screen.getByText('2/1/2024 - 4/30/2024')).toBeInTheDocument()
  })

  it('displays performance metrics slide with detailed metrics', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Navigate to metrics slide
    const nextButton = screen.getByText('Next')
    fireEvent.click(nextButton)
    
    expect(screen.getByText('Performance Metrics')).toBeInTheDocument()
    expect(screen.getByText('3.1%')).toBeInTheDocument() // CTR
    expect(screen.getByText('Click-through Rate')).toBeInTheDocument()
    expect(screen.getByText('$22.06')).toBeInTheDocument() // Cost per conversion
    expect(screen.getByText('Cost per Conversion')).toBeInTheDocument()
    expect(screen.getByText('12')).toBeInTheDocument() // Content pieces
    expect(screen.getByText('Content Pieces')).toBeInTheDocument()
    expect(screen.getByText('75%')).toBeInTheDocument() // Campaign progress
    expect(screen.getByText('Campaign Progress')).toBeInTheDocument()
  })

  it('displays customer journey slide with stage information', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Navigate to journey slide (index 2)
    const slideDots = screen.getAllByRole('button').filter(button => 
      button.className.includes('rounded-full')
    )
    fireEvent.click(slideDots[2])
    
    expect(screen.getByText('Customer Journey')).toBeInTheDocument()
    expect(screen.getByText('Multi-stage campaign strategy and performance')).toBeInTheDocument()
    
    // Check for journey stages
    expect(screen.getByText('Awareness')).toBeInTheDocument()
    expect(screen.getByText('Consideration')).toBeInTheDocument()
    expect(screen.getByText('Conversion')).toBeInTheDocument()
    expect(screen.getByText('Retention')).toBeInTheDocument()
    
    // Check stage metrics
    expect(screen.getByText('75,000')).toBeInTheDocument() // Awareness impressions
    expect(screen.getByText('40,000')).toBeInTheDocument() // Consideration impressions
  })

  it('displays budget slide with financial breakdown', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Navigate to budget slide (index 3)
    const slideDots = screen.getAllByRole('button').filter(button => 
      button.className.includes('rounded-full')
    )
    fireEvent.click(slideDots[3])
    
    expect(screen.getByText('Budget Overview')).toBeInTheDocument()
    expect(screen.getByText('Financial allocation and spending analysis')).toBeInTheDocument()
    
    // Check budget totals
    expect(screen.getByText('$25,000')).toBeInTheDocument()
    expect(screen.getByText('Total Budget')).toBeInTheDocument()
    expect(screen.getByText('$18,750')).toBeInTheDocument()
    expect(screen.getByText(/Spent \(75%\)/)).toBeInTheDocument()
    expect(screen.getByText('$6,250')).toBeInTheDocument()
    expect(screen.getByText('Remaining')).toBeInTheDocument()
    
    // Check budget allocation breakdown
    expect(screen.getByText('Content Creation')).toBeInTheDocument()
    expect(screen.getByText('Paid Advertising')).toBeInTheDocument()
    expect(screen.getByText('Design & Creative')).toBeInTheDocument()
  })

  it('displays audience slide with demographic information', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Navigate to audience slide (index 4)
    const slideDots = screen.getAllByRole('button').filter(button => 
      button.className.includes('rounded-full')
    )
    fireEvent.click(slideDots[4])
    
    expect(screen.getByText('Target Audience')).toBeInTheDocument()
    expect(screen.getByText('Demographic profile and audience insights')).toBeInTheDocument()
    
    // Check demographics
    expect(screen.getByText('25-34 years')).toBeInTheDocument()
    expect(screen.getByText('Age Range')).toBeInTheDocument()
    expect(screen.getByText('All')).toBeInTheDocument()
    
    // Check audience description
    expect(screen.getByText('Environmentally conscious millennials interested in sustainable living')).toBeInTheDocument()
    
    // Check channels
    expect(screen.getByText('Email')).toBeInTheDocument()
    expect(screen.getByText('Social Media')).toBeInTheDocument()
    expect(screen.getByText('Blog')).toBeInTheDocument()
    expect(screen.getByText('Display Ads')).toBeInTheDocument()
  })

  it('displays recommendations slide with actionable insights', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Navigate to recommendations slide (index 5)
    const slideDots = screen.getAllByRole('button').filter(button => 
      button.className.includes('rounded-full')
    )
    fireEvent.click(slideDots[5])
    
    expect(screen.getByText('Recommendations')).toBeInTheDocument()
    expect(screen.getByText('AI-powered insights and optimization suggestions')).toBeInTheDocument()
    
    // Check for recommendations
    expect(screen.getByText('Increase Social Media Budget')).toBeInTheDocument()
    expect(screen.getByText('Optimize Email Content')).toBeInTheDocument()
    expect(screen.getByText('Extend Campaign Duration')).toBeInTheDocument()
    expect(screen.getByText('Create Lookalike Audiences')).toBeInTheDocument()
    
    // Check priority badges
    expect(screen.getByText('High Priority')).toBeInTheDocument()
    expect(screen.getAllByText('Medium Priority')).toHaveLength(2)
    expect(screen.getByText('Low Priority')).toBeInTheDocument()
    
    // Check next steps section
    expect(screen.getByText('Next Steps')).toBeInTheDocument()
    expect(screen.getByText('Schedule Review Meeting')).toBeInTheDocument()
    expect(screen.getByText('Download Action Plan')).toBeInTheDocument()
  })

  it('handles export functionality', () => {
    const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {})
    
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Test PDF export
    fireEvent.click(screen.getByText('Export PDF'))
    expect(consoleSpy).toHaveBeenCalledWith('Exporting presentation as pdf')
    
    // Test PowerPoint export
    fireEvent.click(screen.getByText('Export PowerPoint'))
    expect(consoleSpy).toHaveBeenCalledWith('Exporting presentation as pptx')
    
    // Test print
    fireEvent.click(screen.getByText('Print'))
    expect(consoleSpy).toHaveBeenCalledWith('Exporting presentation as print')
    
    consoleSpy.mockRestore()
  })

  it('disables navigation buttons appropriately at slide boundaries', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    const nextButton = screen.getByText('Next')
    const prevButton = screen.getByText('Previous')
    
    // At first slide, previous should be disabled
    expect(prevButton).toBeDisabled()
    expect(nextButton).not.toBeDisabled()
    
    // Navigate to last slide
    for (let i = 0; i < 5; i++) {
      fireEvent.click(nextButton)
    }
    
    // At last slide, next should be disabled
    expect(nextButton).toBeDisabled()
    expect(prevButton).not.toBeDisabled()
  })

  it('applies correct CSS classes for styling', () => {
    render(<StakeholderPresentation campaign={mockCampaign} className="custom-class" />)
    
    const container = screen.getByText('Stakeholder Presentation').closest('div')
    expect(container).toHaveClass('custom-class')
  })

  it('handles keyboard navigation in fullscreen mode', () => {
    render(<StakeholderPresentation campaign={mockCampaign} />)
    
    // Enter fullscreen
    const presentButton = screen.getByText('Present')
    fireEvent.click(presentButton)
    
    // Should show fullscreen controls
    expect(screen.getByText('1 / 6')).toBeInTheDocument()
  })
})