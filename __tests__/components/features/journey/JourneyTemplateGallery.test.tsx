import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'jest-axe'
import { JourneyTemplateGallery } from '@/components/features/journey/JourneyTemplateGallery'
import type { JourneyTemplate } from '@/lib/types/journey'

// Mock fetch globally
global.fetch = jest.fn()

// Mock lucide-react icons
jest.mock('lucide-react', () => ({
  Copy: () => <div data-testid="copy-icon" />,
  Eye: () => <div data-testid="eye-icon" />,
  Filter: () => <div data-testid="filter-icon" />,
  Search: () => <div data-testid="search-icon" />,
  Settings: () => <div data-testid="settings-icon" />,
  Sparkles: () => <div data-testid="sparkles-icon" />,
  Star: () => <div data-testid="star-icon" />,
  Users: () => <div data-testid="users-icon" />,
  CheckIcon: () => <div data-testid="check-icon" />,
  ChevronDownIcon: () => <div data-testid="chevron-down-icon" />,
  ChevronUpIcon: () => <div data-testid="chevron-up-icon" />,
}))

// Mock all UI components to prevent import issues
jest.mock('@/components/ui/select', () => ({
  Select: ({ children, onValueChange, value, ...props }: any) => {
    const { className, ...domProps } = props;
    return (
      <div data-testid="select" data-value={value} className={className}>
        {React.Children.map(children, child => 
          React.isValidElement(child) ? React.cloneElement(child, { onValueChange }) : child
        )}
      </div>
    )
  },
  SelectTrigger: ({ children, className, ...props }: any) => (
    <button 
      data-testid="select-trigger" 
      role="combobox" 
      className={className} 
      aria-label="Select option"
      aria-expanded="false"
      aria-controls="select-content"
    >
      {children}
    </button>
  ),
  SelectContent: ({ children, onValueChange, className, ...props }: any) => (
    <div 
      data-testid="select-content" 
      className={className} 
      id="select-content"
      role="listbox"
      aria-label="Select options"
    >
      {React.Children.map(children, child => 
        React.isValidElement(child) ? React.cloneElement(child, { onValueChange }) : child
      )}
    </div>
  ),
  SelectItem: ({ children, value, onValueChange, className, ...props }: any) => (
    <div 
      data-testid="select-item" 
      role="option" 
      onClick={() => onValueChange?.(value)} 
      className={className}
      aria-selected="false"
    >
      {children}
    </div>
  ),
  SelectValue: ({ placeholder, className, ...props }: any) => <span data-testid="select-value" className={className}>{placeholder}</span>,
}))

jest.mock('@/components/ui/badge', () => ({
  Badge: ({ children, variant, ...props }: any) => <span data-testid="ui-badge" data-variant={variant} {...props}>{children}</span>,
}))

jest.mock('@/components/ui/card', () => ({
  Card: ({ children, ...props }: any) => <div data-testid="ui-card" {...props}>{children}</div>,
  CardHeader: ({ children, ...props }: any) => <div data-testid="ui-card-header" {...props}>{children}</div>,
  CardContent: ({ children, ...props }: any) => <div data-testid="ui-card-content" {...props}>{children}</div>,
  CardFooter: ({ children, ...props }: any) => <div data-testid="ui-card-footer" {...props}>{children}</div>,
  CardTitle: ({ children, ...props }: any) => <h3 data-testid="ui-card-title" {...props}>{children}</h3>,
  CardDescription: ({ children, ...props }: any) => <p data-testid="ui-card-description" {...props}>{children}</p>,
}))

jest.mock('@/components/ui/dialog', () => ({
  Dialog: ({ children, open }: any) => open ? <div data-testid="dialog">{children}</div> : null,
  DialogContent: ({ children, ...props }: any) => <div data-testid="dialog-content" {...props}>{children}</div>,
  DialogHeader: ({ children, ...props }: any) => <div data-testid="dialog-header" {...props}>{children}</div>,
  DialogTitle: ({ children, ...props }: any) => <h2 data-testid="dialog-title" {...props}>{children}</h2>,
  DialogDescription: ({ children, ...props }: any) => <p data-testid="dialog-description" {...props}>{children}</p>,
}))

jest.mock('@/components/ui/input', () => ({
  Input: (props: any) => <input data-testid="ui-input" {...props} />,
}))

jest.mock('@/components/ui/button', () => ({
  Button: ({ children, ...props }: any) => <button data-testid="ui-button" {...props}>{children}</button>,
}))

jest.mock('@/components/ui/skeleton', () => ({
  Skeleton: (props: any) => <div data-slot="skeleton" data-testid="skeleton" {...props} />,
}))


// Mock the utility functions
jest.mock('@/lib/types/journey', () => ({
  ...jest.requireActual('@/lib/types/journey'),
  getCategoryDisplayName: jest.fn((category: string) => {
    const displayNames: Record<string, string> = {
      CUSTOMER_ACQUISITION: 'Customer Acquisition',
      LEAD_NURTURING: 'Lead Nurturing',
      CUSTOMER_ONBOARDING: 'Customer Onboarding',
      RETENTION: 'Retention',
    }
    return displayNames[category] || category
  }),
  getIndustryDisplayName: jest.fn((industry: string) => {
    const displayNames: Record<string, string> = {
      TECHNOLOGY: 'Technology',
      HEALTHCARE: 'Healthcare',
      FINANCE: 'Finance',
      RETAIL: 'Retail',
      ECOMMERCE: 'E-commerce',
    }
    return displayNames[industry] || industry
  }),
}))

const mockTemplates: JourneyTemplate[] = [
  {
    id: 'template-1',
    name: 'Customer Onboarding Journey',
    description: 'Guide new customers through a smooth onboarding experience',
    industry: 'TECHNOLOGY',
    category: 'CUSTOMER_ONBOARDING',
    stages: [
      {
        id: 'stage-1',
        type: 'awareness',
        title: 'Welcome',
        description: 'Welcome new customers',
        position: { x: 0, y: 0 },
        contentTypes: ['Email'],
        messagingSuggestions: ['Welcome to our platform'],
        objectives: ['Set expectations'],
        metrics: ['Open rate'],
        duration: 1,
        automations: [],
      },
    ],
    metadata: {
      tags: ['onboarding', 'welcome'],
      difficulty: 'beginner',
      estimatedDuration: 7,
      targetAudience: ['new-customers'],
    },
    isActive: true,
    isPublic: true,
    rating: 4.5,
    ratingCount: 25,
    usageCount: 150,
    createdAt: '2024-01-01',
    updatedAt: '2024-01-15',
    createdBy: 'user-1',
  },
  {
    id: 'template-2',
    name: 'Lead Nurturing Campaign',
    description: 'Convert prospects into qualified leads',
    industry: 'FINANCE',
    category: 'LEAD_NURTURING',
    stages: [
      {
        id: 'stage-2',
        type: 'consideration',
        title: 'Educate',
        description: 'Educate prospects',
        position: { x: 100, y: 0 },
        contentTypes: ['Email', 'Content'],
        messagingSuggestions: ['Provide value'],
        objectives: ['Build trust'],
        metrics: ['Engagement rate'],
        duration: 5,
        automations: [],
      },
    ],
    metadata: {
      tags: ['lead-gen', 'nurturing'],
      difficulty: 'intermediate',
      estimatedDuration: 14,
      targetAudience: ['prospects'],
    },
    isActive: true,
    isPublic: true,
    rating: 4.2,
    ratingCount: 18,
    usageCount: 89,
    createdAt: '2024-01-05',
    updatedAt: '2024-01-10',
    createdBy: 'user-2',
  },
  {
    id: 'template-3',
    name: 'E-commerce Retention',
    description: 'Keep customers engaged and coming back',
    industry: 'ECOMMERCE',
    category: 'RETENTION',
    stages: [
      {
        id: 'stage-3',
        type: 'retention',
        title: 'Re-engage',
        description: 'Re-engage customers',
        position: { x: 200, y: 0 },
        contentTypes: ['Email', 'SMS'],
        messagingSuggestions: ['Special offers'],
        objectives: ['Increase retention'],
        metrics: ['Return rate'],
        duration: 10,
        automations: [],
      },
    ],
    metadata: {
      tags: ['retention', 'ecommerce'],
      difficulty: 'advanced',
      estimatedDuration: 30,
      targetAudience: ['existing-customers'],
    },
    isActive: true,
    isPublic: true,
    rating: 4.8,
    ratingCount: 42,
    usageCount: 200,
    createdAt: '2024-01-10',
    updatedAt: '2024-01-20',
    createdBy: 'user-3',
  },
]

const mockFetch = (fetch as jest.MockedFunction<typeof fetch>)

const defaultProps = {
  onSelectTemplate: jest.fn(),
  onPreviewTemplate: jest.fn(),
}

describe('JourneyTemplateGallery', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockFetch.mockClear()
  })

  afterEach(() => {
    mockFetch.mockRestore()
  })

  describe('Loading State', () => {
    it('should show loading skeleton while fetching templates', () => {
      mockFetch.mockImplementation(() => new Promise(() => {})) // Never resolves

      render(<JourneyTemplateGallery {...defaultProps} />)

      expect(document.querySelectorAll('[data-slot="skeleton"]').length).toBeGreaterThan(0)
    })

    it('should have proper accessibility during loading', async () => {
      mockFetch.mockImplementation(() => new Promise(() => {}))
      const { container } = render(<JourneyTemplateGallery {...defaultProps} />)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Initial Rendering', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: false,
          json: () => Promise.resolve({ success: false }),
        } as Response)
      })
    })

    it('should render header and search functionality', async () => {
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Journey Templates')).toBeInTheDocument()
        expect(screen.getByPlaceholderText('Search templates by name, description, or tags...')).toBeInTheDocument()
        expect(screen.getByRole('button', { name: /filters/i })).toBeInTheDocument()
      })
    })

    it('should render template cards after loading', async () => {
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
        expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
        expect(screen.getByText('E-commerce Retention')).toBeInTheDocument()
      })
    })

    it('should display template ratings and metadata correctly', async () => {
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('4.5')).toBeInTheDocument()
        expect(screen.getByText('4.2')).toBeInTheDocument()
        expect(screen.getByText('4.8')).toBeInTheDocument()
        expect(screen.getByText('Technology')).toBeInTheDocument()
        expect(screen.getByText('Finance')).toBeInTheDocument()
      })
    })

    it('should have proper accessibility for template cards', async () => {
      const { container } = render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Search Functionality', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })
    })

    it('should filter templates based on search query', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
        expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'onboarding')

      expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      expect(screen.queryByText('Lead Nurturing Campaign')).not.toBeInTheDocument()
    })

    it('should search by template description', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'prospects')

      expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
    })

    it('should search by tags in metadata', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('E-commerce Retention')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'ecommerce')

      expect(screen.getByText('E-commerce Retention')).toBeInTheDocument()
      expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
    })

    it('should handle empty search results', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'nonexistent')

      expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
      expect(screen.queryByText('Lead Nurturing Campaign')).not.toBeInTheDocument()
    })
  })

  describe('Filter Functionality', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })
    })

    it('should show filters when filter button is clicked', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Journey Templates')).toBeInTheDocument()
      })

      const filterButton = screen.getByRole('button', { name: /filters/i })
      await user.click(filterButton)

      expect(screen.getByText('Select industry')).toBeInTheDocument()
      expect(screen.getByText('Select category')).toBeInTheDocument()
    })

    it('should filter by industry', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
        expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      })

      const filterButton = screen.getByRole('button', { name: /filters/i })
      await user.click(filterButton)

      // Find the industry select - first combobox
      const industrySelect = screen.getAllByRole('combobox')[0]
      await user.click(industrySelect)

      // Wait for the dropdown to appear and click Technology from the select items
      await waitFor(() => {
        expect(screen.getAllByText('Technology').length).toBeGreaterThan(0)
      })
      const technologyOption = screen.getAllByText('Technology').find(el => 
        el.closest('[data-testid="select-item"]')
      )
      if (technologyOption) {
        await user.click(technologyOption)
      }

      // Verify filtering works
      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
        expect(screen.queryByText('Lead Nurturing Campaign')).not.toBeInTheDocument()
      })
    })

    it('should filter by category', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      })

      const filterButton = screen.getByRole('button', { name: /filters/i })
      await user.click(filterButton)

      // Click on category select (second combobox)
      const selects = screen.getAllByRole('combobox')
      await user.click(selects[1])
      
      // Find the Lead Nurturing option from select items
      await waitFor(() => {
        expect(screen.getAllByText('Lead Nurturing').length).toBeGreaterThan(0)
      })
      const leadNurturingOption = screen.getAllByText('Lead Nurturing').find(el => 
        el.closest('[data-testid="select-item"]')
      )
      if (leadNurturingOption) {
        await user.click(leadNurturingOption)
      }

      expect(screen.getByText('Lead Nurturing Campaign')).toBeInTheDocument()
      expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
    })

    it('should combine multiple filters', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('E-commerce Retention')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'retention')

      const filterButton = screen.getByRole('button', { name: /filters/i })
      await user.click(filterButton)

      // Find the first combobox (industry select) since it doesn't have a proper label
      const selectTriggers = screen.getAllByRole('combobox')
      const industrySelect = selectTriggers[0]
      await user.click(industrySelect)
      
      // Find E-commerce option from select items
      await waitFor(() => {
        expect(screen.getAllByText('E-commerce').length).toBeGreaterThan(0)
      })
      const ecommerceOption = screen.getAllByText('E-commerce').find(el => 
        el.closest('[data-testid="select-item"]')
      )
      if (ecommerceOption) {
        await user.click(ecommerceOption)
      }

      expect(screen.getByText('E-commerce Retention')).toBeInTheDocument()
      expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
    })
  })

  describe('Template Actions', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/use') && options?.method === 'POST') {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({ success: true }),
          } as Response)
        }
        if (url.includes('/duplicate') && options?.method === 'POST') {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({ success: true }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })
    })

    it('should call onSelectTemplate when Use Template button is clicked', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const useButtons = screen.getAllByText('Use Template')
      await user.click(useButtons[0])

      expect(defaultProps.onSelectTemplate).toHaveBeenCalledWith(mockTemplates[0])
    })

    it('should call onPreviewTemplate when preview button is clicked', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const previewButtons = screen.getAllByLabelText(/Preview.*template/)
      await user.click(previewButtons[0])

      expect(defaultProps.onPreviewTemplate).toHaveBeenCalledWith(mockTemplates[0])
    })

    it('should duplicate template when duplicate button is clicked', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const duplicateButtons = screen.getAllByLabelText(/Duplicate.*template/)
      await user.click(duplicateButtons[0])

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/journey-templates/template-1/duplicate',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: 'Customer Onboarding Journey (Copy)' }),
        })
      )
    })

    it('should increment usage count when template is used', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const useButtons = screen.getAllByText('Use Template')
      await user.click(useButtons[0])

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/journey-templates/template-1/use',
        { method: 'POST' }
      )
    })

    it('should handle template selection even if usage increment fails', async () => {
      mockFetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/use')) {
          return Promise.resolve({
            ok: false,
            json: () => Promise.resolve({ success: false }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })

      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const useButtons = screen.getAllByText('Use Template')
      await user.click(useButtons[0])

      // Should still call onSelectTemplate even if API fails
      expect(defaultProps.onSelectTemplate).toHaveBeenCalledWith(mockTemplates[0])
    })
  })

  describe('Error Handling', () => {
    it('should handle failed template fetch gracefully', async () => {
      mockFetch.mockImplementation(() =>
        Promise.resolve({
          ok: false,
          json: () => Promise.resolve({ success: false }),
        } as Response)
      )

      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        // Should not crash and should show empty state or handle error
        expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
      })
    })

    it('should handle network errors gracefully', async () => {
      mockFetch.mockImplementation(() => Promise.reject(new Error('Network error')))

      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
      })
    })

    it('should handle duplicate template errors gracefully', async () => {
      mockFetch.mockImplementation((url: string, options?: any) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/duplicate')) {
          return Promise.resolve({
            ok: false,
            json: () => Promise.resolve({ success: false }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })

      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const duplicateButtons = screen.getAllByLabelText(/Duplicate.*template/)
      await user.click(duplicateButtons[0])

      // Should not crash the component
      expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
    })
  })

  describe('Keyboard Navigation', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })
    })

    it('should support keyboard navigation through buttons', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      await user.tab()
      expect(document.activeElement?.tagName.toLowerCase()).toMatch(/input|button/)

      await user.tab()
      expect(document.activeElement?.tagName.toLowerCase()).toMatch(/input|button/)
    })

    it('should activate buttons with Enter key', async () => {
      const user = userEvent.setup()
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const useButton = screen.getAllByText('Use Template')[0]
      useButton.focus()

      await user.keyboard('{Enter}')
      expect(defaultProps.onSelectTemplate).toHaveBeenCalledWith(mockTemplates[0])
    })
  })

  describe('Accessibility', () => {
    beforeEach(() => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })
    })

    it('should meet accessibility standards for the full component', async () => {
      const { container } = render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should maintain accessibility with filters expanded', async () => {
      const user = userEvent.setup()
      const { container } = render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getByText('Journey Templates')).toBeInTheDocument()
      })

      const filterButton = screen.getByRole('button', { name: /filters/i })
      await user.click(filterButton)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should maintain accessibility during search', async () => {
      const user = userEvent.setup()
      const { container } = render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      await user.type(searchInput, 'onboarding')

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should have proper ARIA labels for interactive elements', async () => {
      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search templates by name, description, or tags...')
      expect(searchInput).toBeInTheDocument()

      const filterButton = screen.getByRole('button', { name: /filters/i })
      expect(filterButton).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('should handle empty template list', async () => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: [] },
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })

      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.queryByText('Customer Onboarding Journey')).not.toBeInTheDocument()
      })
    })

    it('should handle templates without ratings', async () => {
      const templatesWithoutRating = mockTemplates.map(template => ({
        ...template,
        rating: undefined,
      }))

      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: templatesWithoutRating },
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })

      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
        expect(screen.queryByText('4.5')).not.toBeInTheDocument()
      })
    })

    it('should handle templates without descriptions', async () => {
      const templatesWithoutDescription = mockTemplates.map(template => ({
        ...template,
        description: undefined,
      }))

      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: templatesWithoutDescription },
            }),
          } as Response)
        }
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ success: true, data: [] }),
        } as Response)
      })

      render(<JourneyTemplateGallery {...defaultProps} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })
    })

    it('should handle optional onPreviewTemplate prop', async () => {
      mockFetch.mockImplementation((url: string) => {
        if (url.includes('/api/journey-templates?pageSize=100')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: { templates: mockTemplates },
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/popular')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        if (url.includes('/api/journey-templates/recommended')) {
          return Promise.resolve({
            ok: true,
            json: () => Promise.resolve({
              success: true,
              data: [],
            }),
          } as Response)
        }
        return Promise.reject(new Error('Unknown URL'))
      })
      
      const user = userEvent.setup()
      render(<JourneyTemplateGallery onSelectTemplate={jest.fn()} />)

      await waitFor(() => {
        expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
      })

      const previewButtons = screen.getAllByLabelText(/Preview.*template/)
      await user.click(previewButtons[0])

      // Should not crash when onPreviewTemplate is not provided
      expect(screen.getAllByText('Customer Onboarding Journey')[0]).toBeInTheDocument()
    })
  })
})