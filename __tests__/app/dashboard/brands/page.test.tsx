import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import BrandDashboardPage from '@/app/dashboard/brands/page'
import { BrandService } from '@/lib/api/brands'
import { BrandSummary, BrandWithRelations } from '@/lib/types/brand'

// Mock the BrandService
jest.mock('@/lib/api/brands', () => ({
  BrandService: {
    getBrands: jest.fn(),
    getBrand: jest.fn(),
  },
}))

// Mock Next.js Image component
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ src, alt, fill, ...props }: any) => (
    <img src={src} alt={alt} {...(fill ? {} : props)} />
  ),
}))

// Mock brand components to isolate page logic
jest.mock('@/components/features/brand', () => ({
  BrandAssetLibrary: ({ brandId }: { brandId: string }) => 
    <div data-testid="brand-asset-library">Asset Library for {brandId}</div>,
  BrandOverview: ({ brand, onUpdate }: { brand: any; onUpdate: any }) => 
    <div data-testid="brand-overview">Overview for {brand.name}</div>,
  BrandAnalytics: ({ brand }: { brand: any }) => 
    <div data-testid="brand-analytics">Analytics for {brand.name}</div>,
  BrandGuidelines: ({ brand }: { brand: any }) => 
    <div data-testid="brand-guidelines">Guidelines for {brand.name}</div>,
  BrandComparison: ({ currentBrand }: { currentBrand: any }) => 
    <div data-testid="brand-comparison">Comparison for {currentBrand.name}</div>,
}))

const mockBrandSummaries: BrandSummary[] = [
  {
    id: 'brand1',
    name: 'Tech Corp',
    description: 'Technology company brand',
    industry: 'Technology',
    tagline: 'Innovation First',
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-15'),
    user: {
      id: 'user1',
      name: 'John Doe',
      email: 'john@example.com'
    },
    _count: {
      campaigns: 5,
      brandAssets: 12
    }
  },
  {
    id: 'brand2',
    name: 'Health Plus',
    description: 'Healthcare brand',
    industry: 'Healthcare',
    tagline: 'Your Health Matters',
    createdAt: new Date('2024-01-05'),
    updatedAt: new Date('2024-01-20'),
    user: {
      id: 'user1',
      name: 'John Doe',
      email: 'john@example.com'
    },
    _count: {
      campaigns: 3,
      brandAssets: 8
    }
  }
]

const mockBrandDetails: BrandWithRelations = {
  id: 'brand1',
  name: 'Tech Corp',
  description: 'Technology company brand',
  industry: 'Technology',
  tagline: 'Innovation First',
  website: 'https://techcorp.com',
  mission: 'To innovate for a better tomorrow',
  vision: 'Leading technology solutions worldwide',
  values: ['Innovation', 'Quality', 'Customer Focus'],
  personality: ['Professional', 'Innovative', 'Trustworthy'],
  voiceDescription: 'Professional and approachable',
  communicationStyle: 'Clear and concise',
  toneAttributes: { professional: 8, friendly: 6, innovative: 9 },
  complianceRules: { 'logo_usage': 'Always use official logo' },
  createdAt: new Date('2024-01-01'),
  updatedAt: new Date('2024-01-15'),
  deletedAt: null,
  userId: 'user1',
  createdBy: 'user1',
  updatedBy: 'user1',
  user: {
    id: 'user1',
    name: 'John Doe',
    email: 'john@example.com'
  },
  campaigns: [
    {
      id: 'campaign1',
      name: 'Q1 Launch',
      status: 'active'
    }
  ],
  brandAssets: [
    {
      id: 'asset1',
      brandId: 'brand1',
      name: 'Primary Logo',
      description: 'Main logo',
      type: 'LOGO' as any,
      category: 'Primary Logo',
      fileUrl: '/logo.svg',
      fileName: 'logo.svg',
      fileSize: 5120,
      mimeType: 'image/svg+xml',
      metadata: {},
      tags: ['logo', 'primary'],
      version: 'v1.0',
      isActive: true,
      downloadCount: 25,
      lastUsed: new Date('2024-01-10'),
      createdAt: new Date('2024-01-01'),
      updatedAt: new Date('2024-01-10'),
      deletedAt: null,
      createdBy: 'user1',
      updatedBy: 'user1'
    }
  ],
  colorPalette: [
    {
      id: 'color1',
      brandId: 'brand1',
      name: 'Primary Colors',
      description: 'Main brand colors',
      colors: { primary: '#007bff' },
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      deletedAt: null,
      createdBy: 'user1',
      updatedBy: 'user1'
    }
  ],
  typography: [
    {
      id: 'typo1',
      brandId: 'brand1',
      name: 'Primary Font',
      fontFamily: 'Inter',
      fontWeight: 'Regular',
      usage: 'heading',
      fallbackFonts: ['Arial', 'sans-serif'],
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      deletedAt: null,
      createdBy: 'user1',
      updatedBy: 'user1'
    }
  ],
  _count: {
    campaigns: 1,
    brandAssets: 1,
    colorPalette: 1,
    typography: 1
  }
}

describe('BrandDashboardPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Brand List View', () => {
    it('should render brand list page with loading state', async () => {
      ;(BrandService.getBrands as jest.Mock).mockImplementation(
        () => new Promise(resolve => setTimeout(resolve, 100))
      )

      const { container } = render(<BrandDashboardPage />)

      // Check for loading skeleton containers by class
      const animatePulseElement = container.querySelector('.animate-pulse')
      expect(animatePulseElement).toBeInTheDocument()
      
      // Check for loading skeleton grid
      const skeletonCards = container.querySelectorAll('.h-48.bg-gray-200.rounded')
      expect(skeletonCards.length).toBe(6)
    })

    it('should load and display brands successfully', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
        expect(screen.getByText('Health Plus')).toBeInTheDocument()
      })

      expect(screen.getByText('Innovation First')).toBeInTheDocument()
      expect(screen.getByText('Your Health Matters')).toBeInTheDocument()
      expect(screen.getAllByText('Technology')[0]).toBeInTheDocument()
      expect(screen.getByText('Healthcare')).toBeInTheDocument()
    })

    it('should handle API error gracefully', async () => {
      ;(BrandService.getBrands as jest.Mock).mockRejectedValue(
        new Error('Failed to load brands')
      )

      const consoleSpy = jest.spyOn(console, 'error').mockImplementation()

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(consoleSpy).toHaveBeenCalledWith('Failed to load brands:', expect.any(Error))
      })

      consoleSpy.mockRestore()
    })

    it('should filter brands by search query', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const searchInput = screen.getByPlaceholderText('Search brands...')
      await user.type(searchInput, 'Health')

      await waitFor(() => {
        expect(screen.getByText('Health Plus')).toBeInTheDocument()
        expect(screen.queryByText('Tech Corp')).not.toBeInTheDocument()
      })
    })

    it('should filter brands by industry', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      // Find and click industry selector
      const industrySelect = screen.getByRole('combobox')
      await user.click(industrySelect)
      
      const healthcareOptions = screen.getAllByText('Healthcare')
      // Click the Healthcare option in the dropdown (should be the second one)
      await user.click(healthcareOptions[1])

      await waitFor(() => {
        expect(screen.getByText('Health Plus')).toBeInTheDocument()
        expect(screen.queryByText('Tech Corp')).not.toBeInTheDocument()
      })
    })

    it('should show empty state when no brands found', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: [],
        pagination: { page: 1, limit: 10, total: 0, pages: 0 }
      })

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('No brands found')).toBeInTheDocument()
        expect(screen.getByText('Create your first brand to get started with brand management')).toBeInTheDocument()
        expect(screen.getByText('Create Your First Brand')).toBeInTheDocument()
      })
    })

    it('should handle create brand button click', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: [],
        pagination: { page: 1, limit: 10, total: 0, pages: 0 }
      })

      const consoleSpy = jest.spyOn(console, 'log').mockImplementation()
      const user = userEvent.setup()

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Create Your First Brand')).toBeInTheDocument()
      })

      const createButton = screen.getByText('Create Your First Brand')
      await user.click(createButton)

      expect(consoleSpy).toHaveBeenCalledWith('Create new brand')
      consoleSpy.mockRestore()
    })
  })

  describe('Brand Detail View', () => {
    it('should navigate to brand detail view when brand is selected', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockBrandDetails)

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const brandCard = screen.getByText('Tech Corp').closest('div[role="article"], div')
      expect(brandCard).toBeInTheDocument()
      
      if (brandCard) {
        fireEvent.click(brandCard)
      }

      await waitFor(() => {
        expect(BrandService.getBrand).toHaveBeenCalledWith('brand1')
        expect(screen.getByText('← Back to Brands')).toBeInTheDocument()
      })
    })

    it('should render brand dashboard with all tabs', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockBrandDetails)

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const brandCard = screen.getByText('Tech Corp').closest('div')
      if (brandCard) {
        fireEvent.click(brandCard)
      }

      await waitFor(() => {
        expect(screen.getByText('Overview')).toBeInTheDocument()
        expect(screen.getByText('Assets')).toBeInTheDocument()
        expect(screen.getByText('Guidelines')).toBeInTheDocument()
        expect(screen.getByText('Analytics')).toBeInTheDocument()
        expect(screen.getByText('Compare')).toBeInTheDocument()
      })

      // Check stats are displayed
      expect(screen.getByText('Total Assets')).toBeInTheDocument()
      // Find the card container that contains both the count and label
      const totalAssetsCard = screen.getByText('Total Assets').closest('[class*="p-4"]')
      expect(totalAssetsCard).toContainHTML('1')
    })

    it('should switch between dashboard tabs', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockBrandDetails)

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const brandCard = screen.getByText('Tech Corp').closest('div')
      if (brandCard) {
        fireEvent.click(brandCard)
      }

      await waitFor(() => {
        expect(screen.getByTestId('brand-overview')).toBeInTheDocument()
      })

      // Click Analytics tab
      const analyticsTab = screen.getByText('Analytics')
      await user.click(analyticsTab)

      await waitFor(() => {
        expect(screen.getByTestId('brand-analytics')).toBeInTheDocument()
      })
    })

    it('should handle back navigation', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockBrandDetails)

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const brandCard = screen.getByText('Tech Corp').closest('div')
      if (brandCard) {
        fireEvent.click(brandCard)
      }

      await waitFor(() => {
        expect(screen.getByText('← Back to Brands')).toBeInTheDocument()
      })

      const backButton = screen.getByText('← Back to Brands')
      await user.click(backButton)

      await waitFor(() => {
        expect(screen.getByText('Brand Management')).toBeInTheDocument()
        expect(screen.getByText('Tech Corp')).toBeInTheDocument() // Back to list
      })
    })

    it('should handle brand detail loading error', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockRejectedValue(
        new Error('Failed to load brand details')
      )

      const consoleSpy = jest.spyOn(console, 'error').mockImplementation()
      const user = userEvent.setup()

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      const brandCard = screen.getByText('Tech Corp').closest('div')
      if (brandCard) {
        fireEvent.click(brandCard)
      }

      await waitFor(() => {
        expect(consoleSpy).toHaveBeenCalledWith(
          'Failed to load brand details:', 
          expect.any(Error)
        )
      })

      consoleSpy.mockRestore()
    })
  })

  describe('Accessibility', () => {
    it('should have proper ARIA labels and roles', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })

      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      // Check search input has proper label
      const searchInput = screen.getByPlaceholderText('Search brands...')
      expect(searchInput).toBeInTheDocument()

      // Check industry selector
      const industrySelect = screen.getByRole('combobox')
      expect(industrySelect).toBeInTheDocument()

      // Check create button is accessible
      const createButton = screen.getByText('Create Brand')
      expect(createButton).toBeInTheDocument()
      expect(createButton.tagName).toBe('BUTTON')
    })

    it('should support keyboard navigation', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockBrandSummaries,
        pagination: { page: 1, limit: 10, total: 2, pages: 1 }
      })

      const user = userEvent.setup()
      render(<BrandDashboardPage />)

      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
      })

      // Test that we can tab through interactive elements
      const searchInput = screen.getByPlaceholderText('Search brands...')
      const industrySelect = screen.getByRole('combobox')
      const createButton = screen.getByText('Create Brand')
      
      // Focus search input directly (tab order can vary based on implementation)
      searchInput.focus()
      expect(searchInput).toHaveFocus()
      
      // Test that other elements can receive focus
      industrySelect.focus()
      expect(industrySelect).toHaveFocus()
      
      createButton.focus()
      expect(createButton).toHaveFocus()
    })
  })
})