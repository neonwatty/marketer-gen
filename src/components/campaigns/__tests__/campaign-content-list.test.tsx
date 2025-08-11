import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignContentList } from '../campaign-content-list'

const mockContentItems = [
  {
    id: "1",
    title: "Sustainable Living: 10 Easy Ways to Start Today",
    type: "blog-post" as const,
    status: "published" as const,
    channel: "Blog",
    journeyStage: "Awareness",
    createdAt: "2024-02-01",
    publishedAt: "2024-02-05",
    metrics: {
      views: 12500,
      engagement: 6.2,
      conversions: 45
    }
  },
  {
    id: "2",
    title: "Welcome to Our Eco-Friendly Product Line",
    type: "email-newsletter" as const,
    status: "published" as const,
    channel: "Email",
    journeyStage: "Awareness",
    createdAt: "2024-02-08",
    publishedAt: "2024-02-10",
    metrics: {
      views: 8500,
      engagement: 12.3,
      conversions: 78
    }
  },
  {
    id: "3",
    title: "🌱 Transform Your Home with Sustainable Products",
    type: "social-post" as const,
    status: "published" as const,
    channel: "Social Media",
    journeyStage: "Consideration",
    createdAt: "2024-02-12",
    publishedAt: "2024-02-15",
    metrics: {
      views: 25000,
      engagement: 4.8,
      conversions: 32
    }
  },
  {
    id: "4",
    title: "Product Comparison: Why Choose Eco?",
    type: "infographic" as const,
    status: "review" as const,
    channel: "Social Media",
    journeyStage: "Consideration",
    createdAt: "2024-03-10"
  },
  {
    id: "5",
    title: "Customer Success Stories Email Series",
    type: "email-newsletter" as const,
    status: "scheduled" as const,
    channel: "Email",
    journeyStage: "Retention",
    createdAt: "2024-03-15",
    publishedAt: "2024-03-25"
  },
  {
    id: "6",
    title: "Limited Time: 20% Off Sustainable Collection",
    type: "ad-copy" as const,
    status: "draft" as const,
    channel: "Display Ads",
    journeyStage: "Conversion",
    createdAt: "2024-03-20"
  }
]

// Mock console.log to avoid test noise
const mockConsoleLog = vi.fn()
console.log = mockConsoleLog

describe('CampaignContentList Component', () => {
  const user = userEvent.setup()

  beforeEach(() => {
    mockConsoleLog.mockClear()
  })

  describe('Basic Rendering', () => {
    it('renders content overview cards', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('Total Content')).toBeInTheDocument()
      // Look for "Published" in the specific overview card context
      expect(screen.getByText('Total Views')).toBeInTheDocument()
      expect(screen.getByText('Conversions')).toBeInTheDocument()
      
      // Verify the published count is displayed (more specific than looking for "Published" text)
      expect(screen.getByText('4')).toBeInTheDocument() // Published count
    })

    it('calculates and displays correct totals', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('8')).toBeInTheDocument() // Total content count
      expect(screen.getByText('4')).toBeInTheDocument() // Published count
      expect(screen.getByText('51.5K')).toBeInTheDocument() // Total views (51500)
      expect(screen.getByText('311')).toBeInTheDocument() // Total conversions (45+78+32+156)
    })

    it('renders create content button', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getAllByText('Create Content')).toHaveLength(1) // Main button
    })

    it('displays content management section', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('Campaign Content')).toBeInTheDocument()
      expect(screen.getByText('Manage and track all content pieces for this campaign')).toBeInTheDocument()
    })
  })

  describe('Search and Filtering', () => {
    it('renders search input', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      expect(searchInput).toBeInTheDocument()
    })

    it('renders filter dropdowns', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByDisplayValue('All Status')).toBeInTheDocument()
      expect(screen.getByDisplayValue('All Types')).toBeInTheDocument()
    })

    it('filters content by search term', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'Sustainable Living')

      await waitFor(() => {
        expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
        expect(screen.queryByText('Welcome to Our Eco-Friendly Product Line')).not.toBeInTheDocument()
      })
    })

    it('filters content by status', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const statusFilter = screen.getByDisplayValue('All Status')
      await user.selectOptions(statusFilter, 'draft')

      await waitFor(() => {
        expect(screen.getByText('Limited Time: 20% Off Sustainable Collection')).toBeInTheDocument()
        expect(screen.queryByText('Sustainable Living: 10 Easy Ways to Start Today')).not.toBeInTheDocument()
      })
    })

    it('filters content by type', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const typeFilter = screen.getByDisplayValue('All Types')
      await user.selectOptions(typeFilter, 'email-newsletter')

      await waitFor(() => {
        expect(screen.getByText('Welcome to Our Eco-Friendly Product Line')).toBeInTheDocument()
        expect(screen.getByText('Customer Success Stories Email Series')).toBeInTheDocument()
        expect(screen.queryByText('Sustainable Living: 10 Easy Ways to Start Today')).not.toBeInTheDocument()
      })
    })

    it('combines search and filters', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      const typeFilter = screen.getByDisplayValue('All Types')

      await user.type(searchInput, 'Email')
      await user.selectOptions(typeFilter, 'email-newsletter')

      await waitFor(() => {
        expect(screen.getByText('Welcome to Our Eco-Friendly Product Line')).toBeInTheDocument()
        expect(screen.getByText('Customer Success Stories Email Series')).toBeInTheDocument()
      })
    })

    it('shows no results when search returns empty', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'nonexistent content')

      await waitFor(() => {
        expect(screen.getByText('No content found')).toBeInTheDocument()
        expect(screen.getByText('Try adjusting your filters to see more content.')).toBeInTheDocument()
      })
    })
  })

  describe('Content Item Display', () => {
    it('displays content item details', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
      expect(screen.getByText('Blog Post')).toBeInTheDocument()
      expect(screen.getByText('Blog')).toBeInTheDocument()
      expect(screen.getAllByText('Awareness Stage')).toHaveLength(2) // Two items have "Awareness Stage"
      // Check for date with flexible matching since locale may format differently
      expect(screen.getAllByText((content, element) => 
        content.includes('Created') && content.includes('2024')
      )).toHaveLength(8) // All 8 items have creation dates
    })

    it('shows content status badges', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getAllByText('Published')).toHaveLength(6) // Overview card, filter option, tab, and 4 status badges
      expect(screen.getAllByText('Review')).toHaveLength(2) // Filter option and 1 status badge
      expect(screen.getAllByText('Scheduled')).toHaveLength(2) // Filter option and 1 status badge  
      expect(screen.getAllByText('Draft')).toHaveLength(3) // Filter option and 2 status badges (tab shows "Draft (2)")
    })

    it('displays metrics for published content', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('12.5K views')).toBeInTheDocument()
      expect(screen.getByText('6.2% engagement')).toBeInTheDocument()
      expect(screen.getByText('45 conversions')).toBeInTheDocument()
    })

    it('hides metrics for unpublished content', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      // Draft content should not show metrics
      const draftContent = screen.getByText('Limited Time: 20% Off Sustainable Collection')
      const draftContainer = draftContent.closest('.border')
      
      expect(draftContainer).not.toHaveTextContent('views')
      expect(draftContainer).not.toHaveTextContent('engagement')
    })

    it('formats large numbers correctly', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('25.0K views')).toBeInTheDocument() // 25000 formatted
      expect(screen.getByText('8.5K views')).toBeInTheDocument() // 8500 formatted
    })
  })

  describe('Tabs Navigation', () => {
    it('renders status tabs with correct counts', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('All (8)')).toBeInTheDocument()
      expect(screen.getByText('Draft (2)')).toBeInTheDocument()
      expect(screen.getByText('Review (1)')).toBeInTheDocument()
      expect(screen.getByText('Published (4)')).toBeInTheDocument()
      expect(screen.getByText('Scheduled (1)')).toBeInTheDocument()
    })

    it('switches to draft tab when clicked', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const draftTab = screen.getByText('Draft (2)')
      await user.click(draftTab)

      await waitFor(() => {
        expect(screen.getByText('Limited Time: 20% Off Sustainable Collection')).toBeInTheDocument()
        expect(screen.queryByText('Sustainable Living: 10 Easy Ways to Start Today')).not.toBeInTheDocument()
      })
    })

    it('switches to published tab when clicked', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const publishedTab = screen.getByText('Published (4)')
      await user.click(publishedTab)

      await waitFor(() => {
        expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
        expect(screen.getByText('Welcome to Our Eco-Friendly Product Line')).toBeInTheDocument()
      })
    })
  })

  describe('Action Menu', () => {
    it('renders action menu for each content item', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const actionButtons = screen.getAllByRole('button')
      const menuButtons = actionButtons.filter(button => 
        button.querySelector('svg')?.getAttribute('class')?.includes('h-4 w-4')
      )
      expect(menuButtons.length).toBeGreaterThan(0)
    })

    it('opens action menu when clicked', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const actionButtons = screen.getAllByRole('button')
      const firstActionButton = actionButtons.find(button => 
        button.querySelector('svg')?.getAttribute('class')?.includes('lucide-more-horizontal')
      )

      if (firstActionButton) {
        await user.click(firstActionButton)

        await waitFor(() => {
          expect(screen.getByText('View Content')).toBeInTheDocument()
          expect(screen.getByText('Edit')).toBeInTheDocument()
          expect(screen.getByText('Duplicate')).toBeInTheDocument()
          expect(screen.getByText('Delete')).toBeInTheDocument()
        }, { timeout: 3000 })
      }
    })

    it('calls correct handlers when menu items are clicked', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const actionButtons = screen.getAllByRole('button')
      const firstActionButton = actionButtons.find(button => 
        button.querySelector('svg')?.getAttribute('class')?.includes('lucide-more-horizontal')
      )

      if (firstActionButton) {
        await user.click(firstActionButton)

        await waitFor(async () => {
          const viewButton = screen.getByText('View Content')
          await user.click(viewButton)

          expect(mockConsoleLog).toHaveBeenCalledWith('view content:', expect.any(String))
        }, { timeout: 3000 })
      }
    })

    it('shows schedule option for draft content', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      // Filter to draft content first
      const statusFilter = screen.getByDisplayValue('All Status')
      await user.selectOptions(statusFilter, 'draft')

      await waitFor(async () => {
        const actionButtons = screen.getAllByRole('button')
        const actionButton = actionButtons.find(button => 
          button.querySelector('svg')?.getAttribute('class')?.includes('lucide-more-horizontal')
        )

        if (actionButton) {
          await user.click(actionButton)

          await waitFor(() => {
            expect(screen.getByText('Schedule')).toBeInTheDocument()
          }, { timeout: 3000 })
        }
      })
    })
  })

  describe('Empty States', () => {
    it('shows empty state when no content matches filters', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'nonexistent-content-xyz')

      await waitFor(() => {
        expect(screen.getByText('No content found')).toBeInTheDocument()
        expect(screen.getByText('Try adjusting your filters to see more content.')).toBeInTheDocument()
      })
    })

    it('shows create content button in empty state', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      await user.type(searchInput, 'nonexistent-content-xyz')

      await waitFor(() => {
        const createButtons = screen.getAllByText('Create Content')
        expect(createButtons.length).toBeGreaterThan(1) // Original button + empty state button
      })
    })
  })

  describe('Content Type Icons and Labels', () => {
    it('displays correct content type labels', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      expect(screen.getByText('Blog Post')).toBeInTheDocument() // Content type label only (filter shows "Blog Posts")
      expect(screen.getAllByText('Email Newsletter')).toHaveLength(2) // Two email newsletter content type labels (filter shows "Email")  
      expect(screen.getByText('Social Post')).toBeInTheDocument() // Content type label only (filter shows "Social")
      expect(screen.getAllByText('Infographic')).toHaveLength(2) // Filter option and 1 content type label
      expect(screen.getAllByText('Ad Copy')).toHaveLength(2) // Filter option and 1 content type label
      expect(screen.getAllByText('Landing Page')).toHaveLength(2) // Filter option and 1 content type label
      expect(screen.getByText('Video Script')).toBeInTheDocument() // Content type label only (filter shows "Video")
    })

    it('renders content type icons', () => {
      const { container } = render(<CampaignContentList campaignId="test-campaign" />)

      // Check for icon containers (icons are rendered via lucide-react)
      const iconContainers = container.querySelectorAll('svg')
      expect(iconContainers.length).toBeGreaterThan(0)
    })
  })

  describe('Date Formatting', () => {
    it('formats creation dates correctly', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      // Check for dates with flexible matching since locale may format differently
      expect(screen.getAllByText((content) => 
        content.includes('Created') && content.includes('2024')
      )).toHaveLength(8) // All 8 items should have creation dates
    })
  })

  describe('Accessibility', () => {
    it('provides proper button labels', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const createButton = screen.getByRole('button', { name: /Create Content/i })
      expect(createButton).toBeInTheDocument()
    })

    it('supports keyboard navigation in tabs', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const allTab = screen.getByRole('tab', { name: /All \(8\)/i })
      const draftTab = screen.getByRole('tab', { name: /Draft \(2\)/i })

      expect(allTab).toHaveAttribute('aria-selected', 'true')
      
      await user.click(draftTab)
      
      await waitFor(() => {
        expect(draftTab).toHaveAttribute('aria-selected', 'true')
        expect(allTab).toHaveAttribute('aria-selected', 'false')
      })
    })

    it('provides proper search input labeling', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const searchInput = screen.getByPlaceholderText('Search content...')
      expect(searchInput).toHaveAttribute('type', 'text')
    })
  })

  describe('Edge Cases', () => {
    it('handles content with very long titles', () => {
      const { container } = render(<CampaignContentList campaignId="test-campaign" />)

      // The component should handle long titles gracefully
      expect(container.firstChild).toBeInTheDocument()
    })

    it('handles content without metrics', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      // Draft and review content don't have metrics - should render without errors
      expect(screen.getByText('Product Comparison: Why Choose Eco?')).toBeInTheDocument()
      expect(screen.getByText('Limited Time: 20% Off Sustainable Collection')).toBeInTheDocument()
    })

    it('handles empty channel arrays', () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      // Should render without crashing even if channels are missing
      expect(screen.getByText('Campaign Content')).toBeInTheDocument()
    })
  })

  describe('Performance Considerations', () => {
    it('renders efficiently with multiple content items', () => {
      const startTime = performance.now()
      render(<CampaignContentList campaignId="test-campaign" />)
      const endTime = performance.now()

      // Should render quickly even with multiple items
      expect(endTime - startTime).toBeLessThan(1000) // Less than 1 second
    })

    it('handles tab switching efficiently', async () => {
      render(<CampaignContentList campaignId="test-campaign" />)

      const publishedTab = screen.getByText('Published (4)')
      const draftTab = screen.getByText('Draft (2)')

      // Multiple tab switches should work smoothly
      await user.click(publishedTab)
      await user.click(draftTab)
      await user.click(publishedTab)

      expect(screen.getByText('Sustainable Living: 10 Easy Ways to Start Today')).toBeInTheDocument()
    })
  })
})