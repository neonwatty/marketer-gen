import { describe, it, expect, vi, beforeEach } from 'vitest'
import { waitFor } from '@testing-library/react'
import { render } from '@/test/test-utils'
import { 
  createMockImageFile, 
  createMockPdfFile, 
  createMockVideoFile,
  mockFileUploadHandlers
} from '@/test/component-helpers'
import { BrandAssetUpload } from '@/components/ui/brand-asset-upload'

describe('BrandAssetUpload Component', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders with default props and card wrapper', () => {
      const { getByText, getByRole } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      // Should render card wrapper by default
      expect(getByText('Upload Brand Assets')).toBeInTheDocument()
      expect(getByText('Upload logos, images, videos, and other brand materials for your marketing campaigns')).toBeInTheDocument()
      
      // Should render file upload component inside
      expect(getByText('Drag & drop files here')).toBeInTheDocument()
      expect(getByRole('button')).toBeInTheDocument()
    })

    it('renders without card wrapper when specified', () => {
      const { getByText, queryByRole } = render(
        <BrandAssetUpload 
          cardWrapper={false}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      // Title should still be present but not in card format
      expect(getByText('Upload Brand Assets')).toBeInTheDocument()
      expect(getByText('Upload logos, images, videos, and other brand materials for your marketing campaigns')).toBeInTheDocument()
      
      // Should not have card structure
      const cardHeaders = document.querySelectorAll('[class*="card-header"]')
      expect(cardHeaders.length).toBe(0)
    })

    it('renders with custom title and description', () => {
      const customTitle = 'Upload Marketing Materials'
      const customDescription = 'Upload your brand assets for the campaign'
      
      const { getByText } = render(
        <BrandAssetUpload 
          title={customTitle}
          description={customDescription}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      expect(getByText(customTitle)).toBeInTheDocument()
      expect(getByText(customDescription)).toBeInTheDocument()
    })

    it('renders with custom max files limit', () => {
      const { getByText } = render(
        <BrandAssetUpload 
          maxFiles={10}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      // Should show updated file limit
      expect(getByText('Maximum 10 files, up to 50 MB each')).toBeInTheDocument()
    })
  })

  describe('Brand Asset Specific Configuration', () => {
    it('accepts brand asset file types', async () => {
      const brandFiles = [
        createMockImageFile('logo.png', 1000000), // 1MB image
        createMockPdfFile('brand-guidelines.pdf', 5000000), // 5MB PDF
        createMockVideoFile('brand-video.mp4', 20000000), // 20MB video
      ]
      
      const { user, getByRole } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      
      await user.upload(input as HTMLInputElement, brandFiles)

      expect(mockFileUploadHandlers.onFilesChange).toHaveBeenCalled()
      const callArgs = mockFileUploadHandlers.onFilesChange.mock.calls[0][0]
      expect(callArgs).toHaveLength(3)
      expect(callArgs[0]).toHaveProperty('name', 'logo.png')
      expect(callArgs[0]).toHaveProperty('type', 'image/png')
      expect(callArgs[1]).toHaveProperty('name', 'brand-guidelines.pdf')
      expect(callArgs[1]).toHaveProperty('type', 'application/pdf')
      expect(callArgs[2]).toHaveProperty('name', 'brand-video.mp4')
      expect(callArgs[2]).toHaveProperty('type', 'video/mp4')
    })

    it('displays correct file size limit for brand assets', () => {
      const { getByText } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      // Brand assets should have 50MB limit
      expect(getByText('Maximum 20 files, up to 50 MB each')).toBeInTheDocument()
    })

    it('handles large brand asset files', async () => {
      // Create a large video file (40MB) which is allowed for brand assets
      const largeVideo = createMockVideoFile('large-brand-video.mp4', 40 * 1024 * 1024)
      
      const { user, getByRole } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, largeVideo)

      expect(mockFileUploadHandlers.onFilesChange).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ 
            name: 'large-brand-video.mp4', 
            size: 40 * 1024 * 1024 
          })
        ])
      )
    })
  })

  describe('Integration with FileUpload', () => {
    it('passes through onUpload handler correctly', async () => {
      const mockFile = createMockImageFile('logo.jpg', 500000)
      const { user, getByRole, getByText, getByLabelText } = render(
        <BrandAssetUpload 
          onFilesChange={mockFileUploadHandlers.onFilesChange}
          onUpload={mockFileUploadHandlers.onUpload}
        />
      )

      // Upload file
      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // Wait for the upload button to appear
      await waitFor(() => {
        expect(getByText('Upload Files')).toBeInTheDocument()
      })

      // Click the upload button
      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      // Wait for the upload handler to be called
      await waitFor(() => {
        expect(mockFileUploadHandlers.onUpload).toHaveBeenCalled()
      }, { timeout: 3000 })
    })

    it('handles disabled state correctly', () => {
      const { container } = render(
        <BrandAssetUpload 
          disabled 
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      const dropzone = container.querySelector('[role="button"]')
      expect(dropzone).toHaveClass('cursor-not-allowed', 'opacity-50')
    })

    it('passes custom className to FileUpload', () => {
      const customClassName = 'custom-upload-class'
      const { container } = render(
        <BrandAssetUpload 
          className={customClassName}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      // The className should be applied to the FileUpload component
      expect(container.querySelector('.custom-upload-class')).toBeInTheDocument()
    })
  })

  describe('Marketing Use Cases', () => {
    it('handles typical marketing file types', async () => {
      const marketingFiles = [
        createMockImageFile('logo.svg', 50000),
        createMockImageFile('banner.webp', 200000),
        createMockPdfFile('brand-guide.pdf', 10000000),
        createMockVideoFile('commercial.mov', 30000000),
      ]
      
      const { user, getByRole } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      
      for (const file of marketingFiles) {
        await user.upload(input, file)
      }

      expect(mockFileUploadHandlers.onFilesChange).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ name: 'logo.svg' }),
          expect.objectContaining({ name: 'banner.webp' }),
          expect.objectContaining({ name: 'brand-guide.pdf' }),
          expect.objectContaining({ name: 'commercial.mov' }),
        ])
      )
    })

    it('supports high-resolution images for print materials', async () => {
      const highResImage = createMockImageFile('print-ready-poster.png', 25 * 1024 * 1024) // 25MB
      
      const { user, getByRole } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, highResImage)

      expect(mockFileUploadHandlers.onFilesChange).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ 
            name: 'print-ready-poster.png',
            size: 25 * 1024 * 1024
          })
        ])
      )
    })

    it('handles multiple logo variations upload', async () => {
      const logoVariations = [
        createMockImageFile('logo-primary.png', 100000),
        createMockImageFile('logo-white.png', 95000),
        createMockImageFile('logo-black.png', 98000),
        createMockImageFile('logo-icon.svg', 25000),
      ]
      
      const { user, getByRole, getByText } = render(
        <BrandAssetUpload 
          title="Upload Logo Variations"
          description="Upload different versions of your brand logo"
          maxFiles={10}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, logoVariations)

      // Should show all files uploaded
      expect(getByText('Files (4/10)')).toBeInTheDocument()
      
      // Should show all logo variations
      expect(getByText('logo-primary.png')).toBeInTheDocument()
      expect(getByText('logo-white.png')).toBeInTheDocument()
      expect(getByText('logo-black.png')).toBeInTheDocument()
      expect(getByText('logo-icon.svg')).toBeInTheDocument()
    })
  })

  describe('Error Handling', () => {
    it('handles upload errors for brand assets', async () => {
      const failingUpload = vi.fn().mockRejectedValue(new Error('Server error'))
      const mockFile = createMockImageFile('brand-asset.jpg', 1000000)
      
      const { user, getByRole, getByText } = render(
        <BrandAssetUpload 
          onFilesChange={mockFileUploadHandlers.onFilesChange}
          onUpload={failingUpload}
        />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      // Should show error state
      await waitFor(() => {
        expect(getByText('Server error')).toBeInTheDocument()
      }, { timeout: 3000 })
    })

    it('shows appropriate error for network issues', async () => {
      const networkError = vi.fn().mockRejectedValue(new Error('Network error'))
      const mockFile = createMockImageFile('logo.png', 500000)
      
      const { user, getByRole, getByText } = render(
        <BrandAssetUpload 
          onFilesChange={mockFileUploadHandlers.onFilesChange}
          onUpload={networkError}
        />
      )

      const input = getByRole('button').querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      // Should handle network errors gracefully
      await waitFor(() => {
        expect(getByText('Network error')).toBeInTheDocument()
      }, { timeout: 3000 })
    })
  })

  describe('Accessibility', () => {
    it('maintains accessibility with card wrapper', () => {
      const { getByRole, getByText } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      // Title should be accessible
      const title = getByText('Upload Brand Assets')
      expect(title).toBeInTheDocument()
      
      // Upload area should be accessible
      const uploadArea = getByRole('button')
      expect(uploadArea).toBeInTheDocument()
    })

    it('maintains accessibility without card wrapper', () => {
      const { getByRole, getByText } = render(
        <BrandAssetUpload 
          cardWrapper={false}
          onFilesChange={mockFileUploadHandlers.onFilesChange} 
        />
      )

      // Title should still be accessible
      const title = getByText('Upload Brand Assets')
      expect(title).toBeInTheDocument()
      
      // Upload area should be accessible
      const uploadArea = getByRole('button')
      expect(uploadArea).toBeInTheDocument()
    })

    it('provides clear instructions for brand asset uploads', () => {
      const { getByText } = render(
        <BrandAssetUpload onFilesChange={mockFileUploadHandlers.onFilesChange} />
      )

      // Should have clear, descriptive text for brand assets
      expect(getByText('Upload logos, images, videos, and other brand materials for your marketing campaigns')).toBeInTheDocument()
      expect(getByText('Maximum 20 files, up to 50 MB each')).toBeInTheDocument()
    })
  })
})