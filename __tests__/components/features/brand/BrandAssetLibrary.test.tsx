import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { BrandAssetLibrary } from '@/components/features/brand/BrandAssetLibrary'
import { BrandAsset, BrandAssetType } from '@/lib/types/brand'

// Mock Next.js Image component
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ src, alt, fill, ...props }: any) => (
    <img src={src} alt={alt} {...(fill ? {} : props)} />
  ),
}))

const mockAssets: BrandAsset[] = [
  {
    id: 'asset1',
    brandId: 'brand1',
    name: 'Primary Logo',
    description: 'Main brand logo for all platforms',
    type: 'LOGO' as BrandAssetType,
    category: 'Primary Logo',
    fileUrl: 'https://example.com/logo.svg',
    fileName: 'logo.svg',
    fileSize: 45320,
    mimeType: 'image/svg+xml',
    metadata: { dimensions: '400x300' },
    tags: ['logo', 'primary', 'brand'],
    version: 'v1.0',
    isActive: true,
    downloadCount: 25,
    lastUsed: new Date('2024-01-15T10:30:00Z'),
    createdAt: new Date('2024-01-01T09:00:00Z'),
    updatedAt: new Date('2024-01-15T10:30:00Z'),
    deletedAt: null,
    createdBy: 'user1',
    updatedBy: 'user1',
  },
  {
    id: 'asset2',
    brandId: 'brand1',
    name: 'Brand Colors',
    description: 'Primary color palette',
    type: 'COLOR_PALETTE' as BrandAssetType,
    category: 'Primary Colors',
    fileUrl: 'https://example.com/colors.pdf',
    fileName: 'brand-colors.pdf',
    fileSize: 892640,
    mimeType: 'application/pdf',
    metadata: { pages: 3, colorCount: 12 },
    tags: ['colors', 'palette'],
    version: 'v2.0',
    isActive: true,
    downloadCount: 15,
    lastUsed: new Date('2024-01-10T15:20:00Z'),
    createdAt: new Date('2024-01-02T11:00:00Z'),
    updatedAt: new Date('2024-01-10T15:20:00Z'),
    deletedAt: null,
    createdBy: 'user1',
    updatedBy: 'user1',
  },
  {
    id: 'asset3',
    brandId: 'brand1',
    name: 'Social Icons',
    description: 'Icon set for social media',
    type: 'ICON' as BrandAssetType,
    category: 'Social Icons',
    fileUrl: 'https://example.com/icons.zip',
    fileName: 'social-icons.zip',
    fileSize: 156780,
    mimeType: 'application/zip',
    metadata: { iconCount: 16 },
    tags: ['icons', 'social'],
    version: 'v1.0',
    isActive: true,
    downloadCount: 8,
    lastUsed: new Date('2024-01-05T13:15:00Z'),
    createdAt: new Date('2024-01-03T16:30:00Z'),
    updatedAt: new Date('2024-01-05T13:15:00Z'),
    deletedAt: null,
    createdBy: 'user1',
    updatedBy: 'user1',
  },
]

describe('BrandAssetLibrary', () => {
  const defaultProps = {
    brandId: 'brand1',
    assets: mockAssets,
    isLoading: false,
  }

  const mockCallbacks = {
    onUpload: jest.fn(),
    onEdit: jest.fn(),
    onDelete: jest.fn(),
    onDownload: jest.fn(),
    onPreview: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('should render the brand asset library with header', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      expect(screen.getByText('Brand Asset Library')).toBeInTheDocument()
      expect(screen.getByText('Manage and organize your brand assets')).toBeInTheDocument()
    })

    it('should render all assets in grid view by default', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      expect(screen.getByText('Primary Logo')).toBeInTheDocument()
      expect(screen.getByText('Brand Colors')).toBeInTheDocument()
      expect(screen.getByText('Social Icons')).toBeInTheDocument()
      
      // Should show asset count
      expect(screen.getByText('3 of 3 assets')).toBeInTheDocument()
    })

    it('should show loading state when isLoading is true', () => {
      render(<BrandAssetLibrary {...defaultProps} isLoading={true} />)
      
      // Should show loading skeleton instead of assets
      expect(screen.queryByText('Primary Logo')).not.toBeInTheDocument()
      expect(screen.getAllByTestId('loading-skeleton')).toHaveLength(8)
    })

    it('should show upload button when onUpload callback is provided', () => {
      render(<BrandAssetLibrary {...defaultProps} {...mockCallbacks} />)
      
      const uploadButtons = screen.getAllByText('Upload Assets')
      expect(uploadButtons.length).toBeGreaterThanOrEqual(1)
    })

    it('should not show upload button when onUpload callback is not provided', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      expect(screen.queryByText('Upload Assets')).not.toBeInTheDocument()
    })
  })

  describe('View Mode Toggle', () => {
    it('should switch between grid and list views', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Should start in grid view
      expect(screen.getByRole('button', { pressed: true })).toHaveAttribute('aria-label', 'grid-view')
      
      // Switch to list view
      const listViewButton = screen.getByRole('button', { name: /list/i })
      await user.click(listViewButton)
      
      // Should now show list view
      expect(screen.getByRole('table')).toBeInTheDocument()
      expect(screen.getByText('Name')).toBeInTheDocument()
      expect(screen.getByText('Type')).toBeInTheDocument()
      expect(screen.getByText('Category')).toBeInTheDocument()
    })
  })

  describe('Search Functionality', () => {
    it('should filter assets based on search query', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      const searchInput = screen.getByPlaceholderText('Search assets...')
      
      // Search for "logo"
      await user.type(searchInput, 'logo')
      
      await waitFor(() => {
        expect(screen.getByText('Primary Logo')).toBeInTheDocument()
        expect(screen.queryByText('Brand Colors')).not.toBeInTheDocument()
        expect(screen.queryByText('Social Icons')).not.toBeInTheDocument()
        expect(screen.getByText('1 of 3 assets')).toBeInTheDocument()
      })
    })

    it('should search by description', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      const searchInput = screen.getByPlaceholderText('Search assets...')
      
      // Search for text in description
      await user.type(searchInput, 'social media')
      
      await waitFor(() => {
        expect(screen.getByText('Social Icons')).toBeInTheDocument()
        expect(screen.queryByText('Primary Logo')).not.toBeInTheDocument()
        expect(screen.queryByText('Brand Colors')).not.toBeInTheDocument()
      })
    })

    it('should search by tags', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      const searchInput = screen.getByPlaceholderText('Search assets...')
      
      // Search for tag
      await user.type(searchInput, 'primary')
      
      await waitFor(() => {
        expect(screen.getByText('Primary Logo')).toBeInTheDocument()
        expect(screen.queryByText('Brand Colors')).not.toBeInTheDocument()
        expect(screen.queryByText('Social Icons')).not.toBeInTheDocument()
      })
    })

    it('should show no results message when search returns empty', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      const searchInput = screen.getByPlaceholderText('Search assets...')
      
      // Search for something that doesn't exist
      await user.type(searchInput, 'nonexistent')
      
      await waitFor(() => {
        expect(screen.getByText('No assets found')).toBeInTheDocument()
        expect(screen.getByText('Try adjusting your filters or search terms')).toBeInTheDocument()
      })
    })
  })

  describe('Type Filtering', () => {
    it('should filter assets by type', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Find and click the type filter dropdown
      const typeFilter = screen.getByDisplayValue('All Types')
      await user.click(typeFilter)
      
      // Select LOGO type
      const logoOption = screen.getByText('Logo')
      await user.click(logoOption)
      
      await waitFor(() => {
        expect(screen.getByText('Primary Logo')).toBeInTheDocument()
        expect(screen.queryByText('Brand Colors')).not.toBeInTheDocument()
        expect(screen.queryByText('Social Icons')).not.toBeInTheDocument()
        expect(screen.getByText('1 of 3 assets')).toBeInTheDocument()
      })
    })
  })

  describe('Category Filtering', () => {
    it('should show category filter when categories exist', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Should show category filter dropdown
      expect(screen.getByDisplayValue('All Categories')).toBeInTheDocument()
    })

    it('should filter assets by category', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Find and click the category filter dropdown
      const categoryFilter = screen.getByDisplayValue('All Categories')
      await user.click(categoryFilter)
      
      // Select Primary Colors category
      const primaryColorsOption = screen.getByText('Primary Colors')
      await user.click(primaryColorsOption)
      
      await waitFor(() => {
        expect(screen.getByText('Brand Colors')).toBeInTheDocument()
        expect(screen.queryByText('Primary Logo')).not.toBeInTheDocument()
        expect(screen.queryByText('Social Icons')).not.toBeInTheDocument()
        expect(screen.getByText('1 of 3 assets')).toBeInTheDocument()
      })
    })
  })

  describe('Sorting', () => {
    it('should sort by name ascending when name sort is clicked', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Click sort dropdown
      const sortButton = screen.getByText('Date')
      await user.click(sortButton)
      
      // Click Name option
      const nameOption = screen.getByText('Name')
      await user.click(nameOption)
      
      await waitFor(() => {
        // Should sort alphabetically - Brand Colors should come first
        const assetCards = screen.getAllByRole('article')
        expect(assetCards[0]).toHaveTextContent('Brand Colors')
        expect(assetCards[1]).toHaveTextContent('Primary Logo')
        expect(assetCards[2]).toHaveTextContent('Social Icons')
      })
    })
  })

  describe('Asset Actions', () => {
    it('should call onUpload when upload button is clicked', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} {...mockCallbacks} />)
      
      const uploadButtons = screen.getAllByText('Upload Assets')
      await user.click(uploadButtons[0])
      
      expect(mockCallbacks.onUpload).toHaveBeenCalledTimes(1)
    })

    it('should call onEdit when edit action is clicked', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} {...mockCallbacks} />)
      
      // Find dropdown menu trigger buttons (small buttons with MoreHorizontal icon)
      const allButtons = screen.getAllByRole('button')
      const dropdownButton = allButtons.find(button => 
        button.className.includes('h-6 w-6 p-0')
      )
      
      if (dropdownButton) {
        await user.click(dropdownButton)
        
        // Click Edit option
        const editOption = screen.getByText('Edit')
        await user.click(editOption)
        
        expect(mockCallbacks.onEdit).toHaveBeenCalledWith(expect.any(Object))
      } else {
        throw new Error('Could not find dropdown menu button')
      }
    })

    it('should call onDelete when delete action is clicked', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} {...mockCallbacks} />)
      
      // Find dropdown menu trigger buttons (small buttons with MoreHorizontal icon)
      const allButtons = screen.getAllByRole('button')
      const dropdownButton = allButtons.find(button => 
        button.className.includes('h-6 w-6 p-0')
      )
      
      if (dropdownButton) {
        await user.click(dropdownButton)
        
        // Click Delete option
        const deleteOption = screen.getByText('Delete')
        await user.click(deleteOption)
        
        expect(mockCallbacks.onDelete).toHaveBeenCalledWith(expect.any(String))
      } else {
        throw new Error('Could not find dropdown menu button')
      }
    })

    it('should call onDownload when download action is clicked', async () => {
      const user = userEvent.setup()
      render(<BrandAssetLibrary {...defaultProps} {...mockCallbacks} />)
      
      // Find dropdown menu trigger buttons (small buttons with MoreHorizontal icon)
      const allButtons = screen.getAllByRole('button')
      const dropdownButton = allButtons.find(button => 
        button.className.includes('h-6 w-6 p-0')
      )
      
      if (dropdownButton) {
        await user.click(dropdownButton)
        
        // Click Download option
        const downloadOption = screen.getByText('Download')
        await user.click(downloadOption)
        
        expect(mockCallbacks.onDownload).toHaveBeenCalledWith(expect.any(Object))
      } else {
        throw new Error('Could not find dropdown menu button')
      }
    })
  })

  describe('Asset Preview', () => {
    it('should open preview modal when asset is clicked', async () => {
      const user = userEvent.setup()
      
      // Create a container for the portal
      const portalContainer = document.createElement('div')
      document.body.appendChild(portalContainer)
      
      render(<BrandAssetLibrary {...defaultProps} />, { container: document.body })
      
      // Click on an asset preview area
      const assetPreview = screen.getAllByTestId('asset-preview')[0]
      await user.click(assetPreview)
      
      // Should open modal with asset details
      await waitFor(() => {
        const dialog = screen.getByRole('dialog')
        expect(dialog).toBeInTheDocument()
        // The modal should contain asset details (check for the one we clicked)
        expect(dialog).toHaveTextContent('Details')
        expect(dialog).toHaveTextContent('Type:')
      })
      
      // Cleanup
      if (document.body.contains(portalContainer)) {
        document.body.removeChild(portalContainer)
      }
    })

    it('should show asset metadata in preview modal', async () => {
      const user = userEvent.setup()
      
      // Create a container for the portal
      const portalContainer = document.createElement('div')
      document.body.appendChild(portalContainer)
      
      render(<BrandAssetLibrary {...defaultProps} />, { container: document.body })
      
      // Click on an asset
      const assetPreview = screen.getAllByTestId('asset-preview')[0]
      await user.click(assetPreview)
      
      await waitFor(() => {
        expect(screen.getByText('Details')).toBeInTheDocument()
        expect(screen.getByText('Type:')).toBeInTheDocument()
        expect(screen.getByText('File size:')).toBeInTheDocument()
        expect(screen.getByText('Created:')).toBeInTheDocument()
        expect(screen.getByText('Downloads:')).toBeInTheDocument()
      })
      
      // Cleanup
      if (document.body.contains(portalContainer)) {
        document.body.removeChild(portalContainer)
      }
    })

    it('should close preview modal when close button is clicked', async () => {
      const user = userEvent.setup()
      
      // Create a container for the portal
      const portalContainer = document.createElement('div')
      document.body.appendChild(portalContainer)
      
      render(<BrandAssetLibrary {...defaultProps} />, { container: document.body })
      
      // Open modal
      const assetPreview = screen.getAllByTestId('asset-preview')[0]
      await user.click(assetPreview)
      
      await waitFor(() => {
        expect(screen.getByRole('dialog')).toBeInTheDocument()
      })
      
      // Close modal
      const closeButton = screen.getByRole('button', { name: /close/i })
      await user.click(closeButton)
      
      await waitFor(() => {
        expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
      })
      
      // Cleanup
      if (document.body.contains(portalContainer)) {
        document.body.removeChild(portalContainer)
      }
    })
  })

  describe('Empty State', () => {
    it('should show empty state when no assets are provided', () => {
      render(<BrandAssetLibrary {...defaultProps} assets={[]} />)
      
      expect(screen.getByText('No assets found')).toBeInTheDocument()
      expect(screen.getByText('Upload your first brand asset to get started')).toBeInTheDocument()
    })

    it('should show upload button in empty state when callback is provided', () => {
      render(<BrandAssetLibrary {...defaultProps} assets={[]} {...mockCallbacks} />)
      
      const uploadButtons = screen.getAllByText('Upload Assets')
      expect(uploadButtons.length).toBeGreaterThanOrEqual(1)
    })
  })

  describe('Asset Type Labels and Colors', () => {
    it('should display correct type labels for different asset types', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      expect(screen.getByText('Logo')).toBeInTheDocument()
      expect(screen.getByText('Color Palette')).toBeInTheDocument()
      expect(screen.getByText('Icon')).toBeInTheDocument()
    })

    it('should apply correct CSS classes for asset type colors', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      const logoBadge = screen.getByText('Logo')
      const colorPaletteBadge = screen.getByText('Color Palette')
      const iconBadge = screen.getByText('Icon')
      
      expect(logoBadge).toHaveClass('bg-blue-100', 'text-blue-800')
      expect(colorPaletteBadge).toHaveClass('bg-purple-100', 'text-purple-800')
      expect(iconBadge).toHaveClass('bg-cyan-100', 'text-cyan-800')
    })
  })

  describe('File Size Formatting', () => {
    it('should format file sizes correctly', () => {
      render(<BrandAssetLibrary {...defaultProps} />)
      
      // Check that file sizes are displayed in readable format
      expect(screen.getByText('44.26 KB')).toBeInTheDocument() // 45320 bytes
      expect(screen.getByText('871.72 KB')).toBeInTheDocument() // 892640 bytes
      expect(screen.getByText('153.11 KB')).toBeInTheDocument() // 156780 bytes
    })
  })
})