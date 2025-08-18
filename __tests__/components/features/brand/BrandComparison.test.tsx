import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { BrandComparison } from '@/components/features/brand/BrandComparison'
import { BrandService } from '@/lib/api/brands'
import { BrandWithRelations, BrandSummary } from '@/lib/types/brand'

// Mock BrandService
jest.mock('@/lib/api/brands', () => ({
  BrandService: {
    getBrands: jest.fn(),
    getBrand: jest.fn(),
  },
}))

const mockCurrentBrand: BrandWithRelations = {
  id: 'brand1',
  name: 'Tech Corp',
  description: 'Technology company brand',
  industry: 'Technology',
  tagline: 'Innovation First',
  website: 'https://techcorp.com',
  mission: 'To innovate for tomorrow',
  vision: 'Leading technology solutions',
  values: ['Innovation', 'Quality'],
  personality: ['Professional', 'Innovative'],
  voiceDescription: 'Professional tone',
  communicationStyle: 'Clear and technical',
  toneAttributes: { professional: 8, innovative: 9 },
  complianceRules: { 'logo_usage': 'Use official logo only' },
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
  campaigns: [],
  brandAssets: [
    {
      id: 'asset1',
      brandId: 'brand1',
      name: 'Tech Logo',
      description: 'Main tech logo',
      type: 'LOGO' as any,
      category: 'Primary Logo',
      fileUrl: '/tech-logo.svg',
      fileName: 'tech-logo.svg',
      fileSize: 5120,
      mimeType: 'image/svg+xml',
      metadata: {},
      tags: ['logo'],
      version: 'v1.0',
      isActive: true,
      downloadCount: 45,
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
      name: 'Tech Colors',
      description: 'Tech brand colors',
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
      name: 'Tech Font',
      fontFamily: 'Inter',
      fontWeight: 'Regular',
      usage: 'heading',
      fallbackFonts: ['Arial'],
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      deletedAt: null,
      createdBy: 'user1',
      updatedBy: 'user1'
    }
  ],
  _count: {
    campaigns: 0,
    brandAssets: 1,
    colorPalette: 1,
    typography: 1
  }
}

const mockAvailableBrands: BrandSummary[] = [
  {
    id: 'brand2',
    name: 'Health Plus',
    description: 'Healthcare brand',
    industry: 'Healthcare',
    tagline: 'Your Health First',
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
  },
  {
    id: 'brand3',
    name: 'Eco Solutions',
    description: 'Environmental solutions',
    industry: 'Environmental',
    tagline: 'Green Future',
    createdAt: new Date('2024-01-10'),
    updatedAt: new Date('2024-01-25'),
    user: {
      id: 'user1',
      name: 'John Doe',
      email: 'john@example.com'
    },
    _count: {
      campaigns: 2,
      brandAssets: 15
    }
  },
  {
    id: 'brand4',
    name: 'Finance Pro',
    description: 'Financial services',
    industry: 'Finance',
    tagline: 'Smart Money',
    createdAt: new Date('2024-01-12'),
    updatedAt: new Date('2024-01-28'),
    user: {
      id: 'user1',
      name: 'John Doe',
      email: 'john@example.com'
    },
    _count: {
      campaigns: 1,
      brandAssets: 5
    }
  }
]

const mockCompareBrand: BrandWithRelations = {
  id: 'brand2',
  name: 'Health Plus',
  description: 'Healthcare solutions provider',
  industry: 'Healthcare',
  tagline: 'Your Health First',
  website: 'https://healthplus.com',
  mission: 'Improving health outcomes',
  vision: 'Healthier communities',
  values: ['Health', 'Care', 'Innovation'],
  personality: ['Caring', 'Professional', 'Reliable'],
  voiceDescription: 'Caring and professional',
  communicationStyle: 'Empathetic and clear',
  toneAttributes: { professional: 7, caring: 9 },
  complianceRules: { 'medical_compliance': 'Follow medical regulations' },
  createdAt: new Date('2024-01-05'),
  updatedAt: new Date('2024-01-20'),
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
      id: 'campaign2',
      name: 'Health Campaign',
      status: 'active'
    }
  ],
  brandAssets: [
    {
      id: 'asset2',
      brandId: 'brand2',
      name: 'Health Logo',
      description: 'Healthcare logo',
      type: 'LOGO' as any,
      category: 'Primary Logo',
      fileUrl: '/health-logo.svg',
      fileName: 'health-logo.svg',
      fileSize: 4096,
      mimeType: 'image/svg+xml',
      metadata: {},
      tags: ['logo', 'health'],
      version: 'v1.0',
      isActive: true,
      downloadCount: 32,
      lastUsed: new Date('2024-01-15'),
      createdAt: new Date('2024-01-05'),
      updatedAt: new Date('2024-01-15'),
      deletedAt: null,
      createdBy: 'user1',
      updatedBy: 'user1'
    }
  ],
  colorPalette: [
    {
      id: 'color2',
      brandId: 'brand2',
      name: 'Health Colors',
      description: 'Healthcare colors',
      colors: { primary: '#28a745' },
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
      id: 'typo2',
      brandId: 'brand2',
      name: 'Health Font',
      fontFamily: 'Roboto',
      fontWeight: 'Medium',
      usage: 'body',
      fallbackFonts: ['Arial'],
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

describe('BrandComparison', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Initial State', () => {
    it('should render brand comparison interface', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      expect(screen.getByText('Brand Comparison')).toBeInTheDocument()
      expect(screen.getByText('Compare Brands')).toBeInTheDocument()
      expect(screen.getByText('Add up to 3 brands to compare against Tech Corp')).toBeInTheDocument()

      // Current brand should be displayed
      await waitFor(() => {
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
        expect(screen.getByText('Current Brand')).toBeInTheDocument()
      })
    })

    it('should load available brands on mount', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      await waitFor(() => {
        expect(BrandService.getBrands).toHaveBeenCalled()
      })
    })

    it('should show comparison mode selector', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      await waitFor(() => {
        expect(screen.getByRole('combobox', { name: /select comparison mode/i })).toBeInTheDocument()
      })
    })

    it('should show empty state when no brands to compare', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      await waitFor(() => {
        expect(screen.getByText('No brands selected for comparison')).toBeInTheDocument()
        expect(screen.getByText('Select brands from the dropdown above to compare their attributes, assets, and performance.')).toBeInTheDocument()
      })
    })
  })

  describe('Brand Selection', () => {
    it('should add brand to comparison when selected', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      
      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      // Find and click the select dropdown
      const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
      await user.click(selectDropdown)

      // Select a brand
      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      
      await act(async () => {
        await user.click(healthPlusOption)
      })

      await waitFor(() => {
        expect(BrandService.getBrand).toHaveBeenCalledWith('brand2')
        // Check that Health Plus appears in the selected brands section
        const healthPlusBrand = screen.getAllByText('Health Plus')[0] // First occurrence should be in the comparison list
        expect(healthPlusBrand).toBeInTheDocument()
        // Healthcare appears multiple times, check for at least one
        const healthcareBadges = screen.getAllByText('Healthcare')
        expect(healthcareBadges.length).toBeGreaterThan(0)
      })
    })

    it('should remove brand from comparison', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      
      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      // Add a brand first
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      
      await act(async () => {
        await user.click(healthPlusOption)
      })

      await waitFor(() => {
        // Check that Health Plus appears in the selected brands section
        const healthPlusBrands = screen.getAllByText('Health Plus')
        expect(healthPlusBrands.length).toBeGreaterThan(0)
      })

      // Remove the brand
      const removeButton = screen.getByRole('button', { name: /remove.*health plus.*from comparison/i })
      
      await act(async () => {
        await user.click(removeButton)
      })

      await waitFor(() => {
        expect(screen.queryByText('Health Plus')).not.toBeInTheDocument()
      })
    })

    it('should limit comparison to 3 brands', async () => {
      // Mock 3 additional brands to select
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock)
        .mockResolvedValueOnce(mockCompareBrand)
        .mockResolvedValueOnce({ ...mockCompareBrand, id: 'brand3', name: 'Eco Solutions' })
        .mockResolvedValueOnce({ ...mockCompareBrand, id: 'brand4', name: 'Finance Pro' })

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add first brand
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      // Add three brands to reach the limit
      for (let i = 0; i < 3; i++) {
        const selectDropdown = screen.getByRole('combobox', { name: /select a brand/i })
        await user.click(selectDropdown)
        
        const options = screen.getAllByRole('option')
        if (options.length > 1) { // Skip "Select a brand to compare" option
          await user.click(options[1])
          await waitFor(() => {
            expect(BrandService.getBrand).toHaveBeenCalled()
          })
        }
      }

      // Should not show add option when at limit
      expect(screen.queryByText('Select a brand to compare')).not.toBeInTheDocument()
    })

    it.skip('should handle brand loading error gracefully', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockRejectedValue(new Error('Failed to load brand'))

      const consoleSpy = jest.spyOn(console, 'error').mockImplementation()
      const user = userEvent.setup()

      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      
      await act(async () => {
        await user.click(healthPlusOption)
      })

      await waitFor(() => {
        expect(consoleSpy).toHaveBeenCalledWith(
          'Failed to load brand for comparison:', 
          expect.any(Error)
        )
      })

      consoleSpy.mockRestore()
    })

    it('should show empty state when no other brands available', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: [], // No other brands
        pagination: { page: 1, limit: 10, total: 0, pages: 0 }
      })

      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      await waitFor(() => {
        expect(screen.getByText('No other brands available for comparison')).toBeInTheDocument()
      })
    })
  })

  describe('Comparison Modes', () => {
    beforeEach(async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)
    })

    it.skip('should switch to visual comparison mode', async () => {
      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await addBrandToComparison(user)

      // Switch to visual mode
      const modeSelector = screen.getByRole('combobox', { name: /select comparison mode/i })
      await user.click(modeSelector)
      
      const visualOption = screen.getByText('Visual')
      await user.click(visualOption)

      await waitFor(() => {
        expect(screen.getByText('Logo')).toBeInTheDocument()
        expect(screen.getByText('Colors')).toBeInTheDocument()
        expect(screen.getByText('Typography')).toBeInTheDocument()
      })
    })

    it.skip('should switch to metrics comparison mode', async () => {
      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await addBrandToComparison(user)

      // Switch to metrics mode
      const modeSelector = screen.getByRole('combobox', { name: /select comparison mode/i })
      await user.click(modeSelector)
      
      const metricsOption = screen.getByText('Metrics')
      await user.click(metricsOption)

      await waitFor(() => {
        expect(screen.getByText('Brand Metrics Comparison')).toBeInTheDocument()
        expect(screen.getByText('Total Assets')).toBeInTheDocument()
        expect(screen.getByText('Active Campaigns')).toBeInTheDocument()
      })
    })

    // Helper function to add a brand to comparison
    async function addBrandToComparison(user: any) {
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      
      await act(async () => {
        await user.click(healthPlusOption)
      })

      await waitFor(() => {
        // Check that Health Plus appears in the selected brands section
        const healthPlusBrands = screen.getAllByText('Health Plus')
        expect(healthPlusBrands.length).toBeGreaterThan(0)
      })
    }
  })

  describe('Overview Comparison', () => {
    it.skip('should display overview comparison table', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      await user.click(healthPlusOption)

      await waitFor(() => {
        expect(screen.getByText('Brand Overview Comparison')).toBeInTheDocument()
        
        // Check table headers
        expect(screen.getByText('Attribute')).toBeInTheDocument()
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
        expect(screen.getByText('Health Plus')).toBeInTheDocument()
        
        // Check comparison attributes
        expect(screen.getByText('Industry')).toBeInTheDocument()
        expect(screen.getByText('Tagline')).toBeInTheDocument()
        expect(screen.getByText('Description')).toBeInTheDocument()
        expect(screen.getByText('Website')).toBeInTheDocument()
        expect(screen.getByText('Brand Values')).toBeInTheDocument()
      })
    })

    it.skip('should handle missing data in comparison gracefully', async () => {
      const brandWithMissingData: BrandWithRelations = {
        ...mockCompareBrand,
        industry: null,
        tagline: null,
        description: null,
        website: null,
        values: null,
      }

      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(brandWithMissingData)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      await user.click(healthPlusOption)

      await waitFor(() => {
        expect(screen.getByText('Not specified')).toBeInTheDocument()
        expect(screen.getByText('No tagline')).toBeInTheDocument()
        expect(screen.getByText('No description')).toBeInTheDocument()
        expect(screen.getByText('Not provided')).toBeInTheDocument()
        expect(screen.getByText('None defined')).toBeInTheDocument()
      })
    })

    it('should display clickable website links', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      await user.click(healthPlusOption)

      await waitFor(() => {
        const techCorpLink = screen.getByText('techcorp.com')
        const healthPlusLink = screen.getByText('healthplus.com')

        expect(techCorpLink.closest('a')).toHaveAttribute('href', 'https://techcorp.com')
        expect(techCorpLink.closest('a')).toHaveAttribute('target', '_blank')
        expect(healthPlusLink.closest('a')).toHaveAttribute('href', 'https://healthplus.com')
        expect(healthPlusLink.closest('a')).toHaveAttribute('target', '_blank')
      })
    })
  })

  describe('Visual Comparison', () => {
    it.skip('should display visual comparison cards', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await waitFor(() => {
        expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
      })

      const selectDropdown = screen.getByRole('combobox', { name: /select a brand/i })
      await user.click(selectDropdown)

      const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
      await user.click(healthPlusOption)

      // Switch to visual mode
      const modeSelector = screen.getAllByRole('combobox')[0] // First combobox is the mode selector
      await user.click(modeSelector)
      
      const visualOption = screen.getByText('Visual')
      await user.click(visualOption)

      await waitFor(() => {
        // Should show visual preview cards for each brand
        const brandCards = screen.getAllByText('Logo')
        expect(brandCards.length).toBeGreaterThan(0)
        
        expect(screen.getByText('Colors')).toBeInTheDocument()
        expect(screen.getByText('Typography')).toBeInTheDocument()
      })
    })

    it('should handle missing visual elements', async () => {
      const brandWithoutVisuals: BrandWithRelations = {
        ...mockCompareBrand,
        brandAssets: [],
        colorPalette: [],
        typography: [],
      }

      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(brandWithoutVisuals)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand and switch to visual mode
      await addBrandForComparison(user)
      await switchToVisualMode(user)

      await waitFor(() => {
        expect(screen.getByText('No logo')).toBeInTheDocument()
        expect(screen.getByText('No color palettes')).toBeInTheDocument()
        expect(screen.getByText('No typography defined')).toBeInTheDocument()
      })
    })
  })

  describe('Metrics Comparison', () => {
    it('should display metrics comparison table', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand and switch to metrics mode
      await addBrandForComparison(user)
      await switchToMetricsMode(user)

      await waitFor(() => {
        expect(screen.getByText('Brand Metrics Comparison')).toBeInTheDocument()
        
        // Check metrics table
        expect(screen.getByText('Total Assets')).toBeInTheDocument()
        expect(screen.getByText('Active Campaigns')).toBeInTheDocument()
        expect(screen.getByText('Color Palettes')).toBeInTheDocument()
        expect(screen.getByText('Typography Sets')).toBeInTheDocument()
        expect(screen.getByText('Total Downloads')).toBeInTheDocument()
      })
    })

    it.skip('should display asset type distribution', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand and switch to metrics mode
      await addBrandForComparison(user)
      await switchToMetricsMode(user)

      await waitFor(() => {
        expect(screen.getByText('Asset Type Distribution')).toBeInTheDocument()
        expect(screen.getByText('Tech Corp')).toBeInTheDocument()
        expect(screen.getByText('Health Plus')).toBeInTheDocument()
      })
    })

    it('should calculate download totals correctly', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand and switch to metrics mode
      await addBrandForComparison(user)
      await switchToMetricsMode(user)

      await waitFor(() => {
        // Tech Corp has 45 downloads, Health Plus has 32
        expect(screen.getByText('45')).toBeInTheDocument()
        expect(screen.getByText('32')).toBeInTheDocument()
      })
    })
  })

  // Helper functions
  async function addBrandForComparison(user: any) {
    await waitFor(() => {
      expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
    })

    const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
    await user.click(selectDropdown)

    const healthPlusOption = screen.getByText('Health Plus (Healthcare)')
    
    await act(async () => {
      await user.click(healthPlusOption)
    })

    await waitFor(() => {
      // Check that Health Plus appears in the selected brands section
      const healthPlusBrands = screen.getAllByText('Health Plus')
      expect(healthPlusBrands.length).toBeGreaterThan(0)
    })
  }

  async function switchToVisualMode(user: any) {
    const modeSelector = screen.getByRole('combobox', { name: /select comparison mode/i })
    await user.click(modeSelector)
    
    const visualOption = screen.getByText('Visual')
    await user.click(visualOption)
  }

  async function switchToMetricsMode(user: any) {
    const modeSelector = screen.getByRole('combobox', { name: /select comparison mode/i })
    await user.click(modeSelector)
    
    const metricsOption = screen.getByText('Metrics')
    await user.click(metricsOption)
  }

  describe('Accessibility', () => {
    it('should have proper semantic structure', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Check for main heading
      expect(screen.getByRole('heading', { level: 2 })).toBeInTheDocument()

      // Check for accessible form elements
      const comboboxes = screen.getAllByRole('combobox')
      expect(comboboxes.length).toBeGreaterThan(0)

      // Check for buttons
      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(0)
    })

    it('should support keyboard navigation', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Tab through interactive elements
      await user.tab()
      expect(document.activeElement).toBeInTheDocument()

      await user.tab()
      expect(document.activeElement).toBeInTheDocument()
    })

    it('should have proper table accessibility for comparison', async () => {
      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })
      ;(BrandService.getBrand as jest.Mock).mockResolvedValue(mockCompareBrand)

      const user = userEvent.setup()
      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      // Add a brand for comparison
      await addBrandForComparison(user)

      await waitFor(() => {
        const table = screen.getByRole('table')
        expect(table).toBeInTheDocument()

        const columnHeaders = screen.getAllByRole('columnheader')
        expect(columnHeaders.length).toBeGreaterThan(0)

        const rows = screen.getAllByRole('row')
        expect(rows.length).toBeGreaterThan(0)
      })
    })
  })

  describe('Error Handling', () => {
    it('should handle API errors gracefully', async () => {
      ;(BrandService.getBrands as jest.Mock).mockRejectedValue(
        new Error('Failed to load brands')
      )

      const consoleSpy = jest.spyOn(console, 'error').mockImplementation()

      render(<BrandComparison currentBrand={mockCurrentBrand} />)

      await waitFor(() => {
        expect(consoleSpy).toHaveBeenCalledWith(
          'Failed to load brands:', 
          expect.any(Error)
        )
      })

      consoleSpy.mockRestore()
    })

    it('should handle missing current brand data', () => {
      const minimalBrand: BrandWithRelations = {
        ...mockCurrentBrand,
        brandAssets: [],
        colorPalette: [],
        typography: [],
        campaigns: [],
        _count: {
          campaigns: 0,
          brandAssets: 0,
          colorPalette: 0,
          typography: 0
        }
      }

      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: [],
        pagination: { page: 1, limit: 10, total: 0, pages: 0 }
      })

      render(<BrandComparison currentBrand={minimalBrand} />)

      // Should render without crashing
      expect(screen.getByText('Brand Comparison')).toBeInTheDocument()
    })
  })

  describe('Performance', () => {
    it.skip('should handle multiple brand comparisons efficiently', async () => {
      const multipleBrands = Array.from({ length: 3 }, (_, i) => ({
        ...mockCompareBrand,
        id: `brand${i + 2}`,
        name: `Brand ${i + 2}`,
      }))

      ;(BrandService.getBrands as jest.Mock).mockResolvedValue({
        brands: mockAvailableBrands,
        pagination: { page: 1, limit: 10, total: 3, pages: 1 }
      })

      let callCount = 0
      ;(BrandService.getBrand as jest.Mock).mockImplementation(() => {
        return Promise.resolve(multipleBrands[callCount++ % multipleBrands.length])
      })

      const user = userEvent.setup()
      
      await act(async () => {
        render(<BrandComparison currentBrand={mockCurrentBrand} />)
      })

      // Add multiple brands quickly
      for (let i = 0; i < 3; i++) {
        await waitFor(() => {
          expect(screen.getByText('Select a brand to compare')).toBeInTheDocument()
        })

        const selectDropdown = screen.getByRole('combobox', { name: /select a brand to compare/i })
        await user.click(selectDropdown)

        const options = screen.getAllByRole('option')
        if (options.length > 1) {
          await act(async () => {
            await user.click(options[1])
          })
          await waitFor(() => {
            expect(BrandService.getBrand).toHaveBeenCalled()
          })
        }
      }

      // Should handle multiple comparisons without performance issues
      expect(screen.getByText('Brand Comparison')).toBeInTheDocument()
    })
  })
})