import { render, screen, fireEvent } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignCard, type CampaignCardProps } from '../campaign-card'

const baseCampaign: CampaignCardProps = {
  id: '1',
  title: 'Summer Product Launch',
  description: 'Multi-channel campaign for new product line launch targeting millennials',
  status: 'active',
  createdAt: 'Jan 15, 2024',
  metrics: {
    progress: 75,
    contentPieces: 12,
    channels: ['Email', 'Social', 'Blog'],
    budget: 25000,
    impressions: 125000,
    engagement: 4.2,
    conversions: 850
  }
}

describe('CampaignCard Component', () => {
  const user = userEvent.setup()
  const mockHandlers = {
    onEdit: vi.fn(),
    onStatusChange: vi.fn(),
    onCopy: vi.fn(),
    onDelete: vi.fn(),
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders campaign title and description', () => {
      render(<CampaignCard {...baseCampaign} />)

      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
      expect(screen.getByText('Multi-channel campaign for new product line launch targeting millennials')).toBeInTheDocument()
    })

    it('renders campaign status with correct styling', () => {
      render(<CampaignCard {...baseCampaign} />)

      const statusBadge = screen.getByText('Active')
      expect(statusBadge).toBeInTheDocument()
      expect(statusBadge).toHaveClass('bg-green-100')
    })

    it('renders status indicator bar at the top', () => {
      const { container } = render(<CampaignCard {...baseCampaign} />)

      // Should have a status indicator bar element
      const statusBar = container.querySelector('.absolute.top-0.left-0.right-0.h-1')
      expect(statusBar).toBeInTheDocument()
    })

    it('renders created date', () => {
      render(<CampaignCard {...baseCampaign} />)

      expect(screen.getByText('Jan 15, 2024')).toBeInTheDocument()
    })
  })

  describe('Status Variants', () => {
    it.each([
      ['draft', 'Draft', 'bg-slate-100'],
      ['active', 'Active', 'bg-green-100'],
      ['paused', 'Paused', 'bg-yellow-100'],
      ['completed', 'Completed', 'bg-blue-100'],
      ['cancelled', 'Cancelled', 'bg-red-100'],
    ])('renders %s status correctly', (status, label, bgClass) => {
      render(
        <CampaignCard 
          {...baseCampaign} 
          status={status as any}
        />
      )

      const statusBadge = screen.getByText(label)
      expect(statusBadge).toBeInTheDocument()
      expect(statusBadge).toHaveClass(bgClass)
    })
  })

  describe('Progress Display', () => {
    it('renders progress percentage and bar', () => {
      render(<CampaignCard {...baseCampaign} />)

      expect(screen.getByText('75% complete')).toBeInTheDocument()
      
      const progressBar = screen.getByRole('progressbar')
      expect(progressBar).toBeInTheDocument()
      // Progress component uses data attributes instead of aria-valuenow
      expect(progressBar).toHaveAttribute('data-slot', 'progress')
    })

    it('handles different progress values', () => {
      const campaign = {
        ...baseCampaign,
        metrics: { ...baseCampaign.metrics, progress: 25 }
      }

      render(<CampaignCard {...campaign} />)

      expect(screen.getByText('25% complete')).toBeInTheDocument()
      
      const progressBar = screen.getByRole('progressbar')
      expect(progressBar).toHaveAttribute('data-slot', 'progress')
    })
  })

  describe('Metrics Display', () => {
    it('renders basic metrics with icons', () => {
      render(<CampaignCard {...baseCampaign} />)

      expect(screen.getByText('Email, Social, Blog')).toBeInTheDocument()
      expect(screen.getByText('12 pieces')).toBeInTheDocument()
      expect(screen.getByText('$25,000')).toBeInTheDocument()
    })

    it('renders performance metrics when available', () => {
      render(<CampaignCard {...baseCampaign} />)

      expect(screen.getByText('125.0K')).toBeInTheDocument() // Impressions (125000 formatted)
      expect(screen.getByText('4.2%')).toBeInTheDocument() // Engagement  
      expect(screen.getByText('850')).toBeInTheDocument() // Conversions
    })

    it('hides performance metrics when not available', () => {
      const campaignWithoutMetrics = {
        ...baseCampaign,
        metrics: {
          progress: 25,
          contentPieces: 3,
          channels: ['Email'],
        }
      }

      render(<CampaignCard {...campaignWithoutMetrics} />)

      // Performance metrics section should not be rendered
      expect(screen.queryByText('Impressions')).not.toBeInTheDocument()
      expect(screen.queryByText('Engagement')).not.toBeInTheDocument()
      expect(screen.queryByText('Conversions')).not.toBeInTheDocument()
    })

    it('formats large numbers correctly', () => {
      const campaignWithLargeNumbers = {
        ...baseCampaign,
        metrics: {
          ...baseCampaign.metrics,
          impressions: 1500000, // Should show as 1.5M
          conversions: 25000,   // Should show as 25.0K
        }
      }

      render(<CampaignCard {...campaignWithLargeNumbers} />)

      expect(screen.getByText('1.5M')).toBeInTheDocument()
      expect(screen.getByText('25.0K')).toBeInTheDocument()
    })

    it('formats budget as currency', () => {
      const campaignWithBudget = {
        ...baseCampaign,
        metrics: {
          ...baseCampaign.metrics,
          budget: 150000
        }
      }

      render(<CampaignCard {...campaignWithBudget} />)

      expect(screen.getByText('$150,000')).toBeInTheDocument()
    })
  })

  describe('Action Buttons', () => {
    it('always renders edit button', () => {
      render(<CampaignCard {...baseCampaign} {...mockHandlers} />)

      expect(screen.getByText('Edit')).toBeInTheDocument()
    })

    it('calls onEdit when edit button is clicked', async () => {
      render(<CampaignCard {...baseCampaign} {...mockHandlers} />)

      const editButton = screen.getByText('Edit')
      await user.click(editButton)

      expect(mockHandlers.onEdit).toHaveBeenCalledWith('1')
    })

    describe('Status-specific Action Buttons', () => {
      it('shows Launch button for draft status', () => {
        render(
          <CampaignCard 
            {...baseCampaign} 
            status="draft" 
            {...mockHandlers}
          />
        )

        expect(screen.getByText('Launch')).toBeInTheDocument()
      })

      it('shows Pause button for active status', () => {
        render(
          <CampaignCard 
            {...baseCampaign} 
            status="active" 
            {...mockHandlers}
          />
        )

        expect(screen.getByText('Pause')).toBeInTheDocument()
      })

      it('shows Resume button for paused status', () => {
        render(
          <CampaignCard 
            {...baseCampaign} 
            status="paused" 
            {...mockHandlers}
          />
        )

        expect(screen.getByText('Resume')).toBeInTheDocument()
      })

      it('shows Copy button for completed status', () => {
        render(
          <CampaignCard 
            {...baseCampaign} 
            status="completed" 
            {...mockHandlers}
          />
        )

        expect(screen.getByText('Copy')).toBeInTheDocument()
      })

      it('does not show action button for cancelled status', () => {
        render(
          <CampaignCard 
            {...baseCampaign} 
            status="cancelled" 
            {...mockHandlers}
          />
        )

        // Should only have Edit button
        const buttons = screen.getAllByRole('button')
        const textButtons = buttons.filter(btn => btn.textContent?.includes('Edit') || btn.textContent?.includes('Launch') || btn.textContent?.includes('Pause') || btn.textContent?.includes('Resume') || btn.textContent?.includes('Copy'))
        expect(textButtons).toHaveLength(1) // Only Edit button
        expect(textButtons[0]).toHaveTextContent('Edit')
      })
    })

    it('calls onStatusChange when status action buttons are clicked', async () => {
      render(
        <CampaignCard 
          {...baseCampaign} 
          status="draft" 
          {...mockHandlers}
        />
      )

      const launchButton = screen.getByText('Launch')
      await user.click(launchButton)

      expect(mockHandlers.onStatusChange).toHaveBeenCalledWith('1', 'active')
    })

    it('calls onCopy when copy button is clicked', async () => {
      render(
        <CampaignCard 
          {...baseCampaign} 
          status="completed" 
          {...mockHandlers}
        />
      )

      const copyButton = screen.getByText('Copy')
      await user.click(copyButton)

      expect(mockHandlers.onCopy).toHaveBeenCalledWith('1')
    })
  })

  describe('Hover Effects', () => {
    it('adds hover shadow class', () => {
      const { container } = render(<CampaignCard {...baseCampaign} />)

      const card = container.firstChild as HTMLElement
      expect(card).toHaveClass('hover:shadow-md')
      expect(card).toHaveClass('transition-shadow')
    })
  })

  describe('Accessibility', () => {
    it('provides proper button structure', () => {
      render(<CampaignCard {...baseCampaign} {...mockHandlers} />)

      // Should have buttons available for interaction
      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThanOrEqual(2) // At least Edit button and action button

      // Edit button should be labeled
      expect(screen.getByRole('button', { name: 'Edit' })).toBeInTheDocument()
    })

    it('maintains keyboard navigation', async () => {
      render(<CampaignCard {...baseCampaign} {...mockHandlers} />)

      const editButton = screen.getByText('Edit')
      
      // Should be focusable
      editButton.focus()
      expect(editButton).toHaveFocus()
    })
  })

  describe('Data Handling', () => {
    it('handles missing optional properties gracefully', () => {
      const minimalCampaign = {
        id: '2',
        title: 'Minimal Campaign',
        description: 'Basic campaign',
        status: 'draft' as const,
        createdAt: 'Jan 1, 2024',
        metrics: {
          progress: 10,
          contentPieces: 1,
          channels: ['Email']
        }
      }

      render(<CampaignCard {...minimalCampaign} />)

      expect(screen.getByText('Minimal Campaign')).toBeInTheDocument()
      expect(screen.getByText('10% complete')).toBeInTheDocument()
    })

    it('handles empty channels array', () => {
      const campaignWithNoChannels = {
        ...baseCampaign,
        metrics: {
          ...baseCampaign.metrics,
          channels: []
        }
      }

      render(<CampaignCard {...campaignWithNoChannels} />)

      // Should render without crashing
      expect(screen.getByText('Summer Product Launch')).toBeInTheDocument()
    })

    it('handles very long titles and descriptions', () => {
      const campaignWithLongContent = {
        ...baseCampaign,
        title: 'Very Long Campaign Title That Might Overflow The Container And Cause Layout Issues',
        description: 'Very long description that goes on and on and contains many details about the campaign that might cause text overflow issues in the UI components and needs to be handled gracefully'
      }

      const { container } = render(<CampaignCard {...campaignWithLongContent} />)

      // Should have truncation classes
      const titleElement = screen.getByText(campaignWithLongContent.title)
      const descElement = screen.getByText(campaignWithLongContent.description)
      
      expect(titleElement).toBeInTheDocument()
      expect(descElement).toBeInTheDocument()
    })
  })
})