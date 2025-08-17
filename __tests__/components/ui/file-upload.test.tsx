import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { FileUpload } from '@/components/ui/file-upload'

// Mock Next.js Image component
jest.mock('next/image', () => ({
  __esModule: true,
  default: ({ src, alt, ...props }: any) => (
    <img src={src} alt={alt} {...props} />
  ),
}))

// Helper to create mock files
const createMockFile = (name: string, type: string, size: number = 1024) => {
  const file = new File(['test content'], name, { type })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

describe('FileUpload', () => {
  const defaultProps = {
    onFilesChange: jest.fn(),
    maxFiles: 5,
    maxSize: 10 * 1024 * 1024, // 10MB
    accept: {
      'image/*': ['.png', '.jpg', '.jpeg', '.svg'],
      'application/pdf': ['.pdf'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
    },
  }

  const mockCallbacks = {
    onFilesChange: jest.fn(),
    onUpload: jest.fn(),
    onRemove: jest.fn(),
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('should render file upload area with correct text', () => {
      render(<FileUpload {...defaultProps} />)
      
      expect(screen.getByText('Click to upload or drag and drop')).toBeInTheDocument()
      expect(screen.getByText('PNG, JPG, SVG, PDF, DOCX up to 10 MB')).toBeInTheDocument()
    })

    it('should show upload button when onUpload callback is provided', () => {
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      expect(screen.getByText('Upload Files')).toBeInTheDocument()
    })

    it('should not show upload button when onUpload callback is not provided', () => {
      render(<FileUpload {...defaultProps} />)
      
      expect(screen.queryByText('Upload Files')).not.toBeInTheDocument()
    })

    it('should show progress when uploadProgress is provided', () => {
      render(<FileUpload {...defaultProps} uploadProgress={75} />)
      
      expect(screen.getByText('Uploading... 75%')).toBeInTheDocument()
      expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '75')
    })
  })

  describe('File Selection via Click', () => {
    it('should trigger file input when upload area is clicked', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      const fileInput = screen.getByTestId('file-input')
      
      // Mock the click method
      const clickSpy = jest.spyOn(fileInput, 'click')
      
      await user.click(uploadArea)
      
      expect(clickSpy).toHaveBeenCalled()
    })

    it('should handle file selection via input', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const testFile = createMockFile('test.png', 'image/png')
      
      await user.upload(fileInput, testFile)
      
      expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith([testFile])
    })

    it('should handle multiple file selection', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const testFiles = [
        createMockFile('test1.png', 'image/png'),
        createMockFile('test2.jpg', 'image/jpeg'),
      ]
      
      await user.upload(fileInput, testFiles)
      
      expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith(testFiles)
    })
  })

  describe('Drag and Drop', () => {
    it('should handle drag enter and leave events', () => {
      render(<FileUpload {...defaultProps} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      
      // Drag enter should add drag-over state
      fireEvent.dragEnter(uploadArea)
      expect(uploadArea).toHaveClass('border-primary')
      
      // Drag leave should remove drag-over state
      fireEvent.dragLeave(uploadArea)
      expect(uploadArea).not.toHaveClass('border-primary')
    })

    it('should handle file drop', async () => {
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      const testFile = createMockFile('test.png', 'image/png')
      
      const dropEvent = new Event('drop', { bubbles: true })
      Object.defineProperty(dropEvent, 'dataTransfer', {
        value: {
          files: [testFile],
          types: ['Files'],
        },
      })
      
      fireEvent(uploadArea, dropEvent)
      
      await waitFor(() => {
        expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith([testFile])
      })
    })

    it('should prevent default drag events', () => {
      render(<FileUpload {...defaultProps} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      
      const dragOverEvent = new Event('dragover')
      const preventDefaultSpy = jest.spyOn(dragOverEvent, 'preventDefault')
      
      fireEvent(uploadArea, dragOverEvent)
      
      expect(preventDefaultSpy).toHaveBeenCalled()
    })
  })

  describe('File Validation', () => {
    it('should reject files that exceed max size', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const largeFile = createMockFile('large.png', 'image/png', 15 * 1024 * 1024) // 15MB
      
      await user.upload(fileInput, largeFile)
      
      expect(screen.getByText('File size must be less than 10 MB')).toBeInTheDocument()
      expect(mockCallbacks.onFilesChange).not.toHaveBeenCalled()
    })

    it('should reject files with unsupported types', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const unsupportedFile = createMockFile('test.txt', 'text/plain')
      
      await user.upload(fileInput, unsupportedFile)
      
      expect(screen.getByText('File type not supported')).toBeInTheDocument()
      expect(mockCallbacks.onFilesChange).not.toHaveBeenCalled()
    })

    it('should reject when max files limit is exceeded', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} maxFiles={2} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const testFiles = [
        createMockFile('test1.png', 'image/png'),
        createMockFile('test2.png', 'image/png'),
        createMockFile('test3.png', 'image/png'),
      ]
      
      await user.upload(fileInput, testFiles)
      
      expect(screen.getByText('Maximum 2 files allowed')).toBeInTheDocument()
      expect(mockCallbacks.onFilesChange).not.toHaveBeenCalled()
    })

    it('should validate against existing files count', async () => {
      const user = userEvent.setup()
      const existingFiles = [createMockFile('existing.png', 'image/png')]
      
      render(<FileUpload {...defaultProps} maxFiles={2} value={existingFiles} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const newFiles = [
        createMockFile('new1.png', 'image/png'),
        createMockFile('new2.png', 'image/png'),
      ]
      
      await user.upload(fileInput, newFiles)
      
      expect(screen.getByText('Maximum 2 files allowed')).toBeInTheDocument()
      expect(mockCallbacks.onFilesChange).not.toHaveBeenCalled()
    })
  })

  describe('File Display and Management', () => {
    it('should display selected files with previews', () => {
      const testFiles = [
        createMockFile('test.png', 'image/png'),
        createMockFile('document.pdf', 'application/pdf'),
      ]
      
      render(<FileUpload {...defaultProps} value={testFiles} />)
      
      expect(screen.getByText('test.png')).toBeInTheDocument()
      expect(screen.getByText('document.pdf')).toBeInTheDocument()
      expect(screen.getByText('1 KB')).toBeInTheDocument() // File size
    })

    it('should show image previews for image files', () => {
      const imageFile = createMockFile('test.png', 'image/png')
      // Mock URL.createObjectURL
      global.URL.createObjectURL = jest.fn(() => 'mock-url')
      
      render(<FileUpload {...defaultProps} value={[imageFile]} />)
      
      expect(screen.getByAltText('test.png')).toBeInTheDocument()
      expect(global.URL.createObjectURL).toHaveBeenCalledWith(imageFile)
    })

    it('should show file type icons for non-image files', () => {
      const pdfFile = createMockFile('document.pdf', 'application/pdf')
      
      render(<FileUpload {...defaultProps} value={[pdfFile]} />)
      
      expect(screen.getByText('📄')).toBeInTheDocument() // PDF icon
    })

    it('should handle file removal', async () => {
      const user = userEvent.setup()
      const testFiles = [
        createMockFile('test1.png', 'image/png'),
        createMockFile('test2.png', 'image/png'),
      ]
      
      render(<FileUpload {...defaultProps} value={testFiles} {...mockCallbacks} />)
      
      const removeButtons = screen.getAllByRole('button', { name: /remove/i })
      await user.click(removeButtons[0])
      
      if (mockCallbacks.onRemove) {
        expect(mockCallbacks.onRemove).toHaveBeenCalledWith(0)
      } else {
        expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith([testFiles[1]])
      }
    })
  })

  describe('URL File Addition', () => {
    it('should show URL input when allowUrls is true', () => {
      render(<FileUpload {...defaultProps} allowUrls={true} />)
      
      expect(screen.getByText('Add from URL')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Enter file URL')).toBeInTheDocument()
    })

    it('should not show URL input by default', () => {
      render(<FileUpload {...defaultProps} />)
      
      expect(screen.queryByText('Add from URL')).not.toBeInTheDocument()
    })

    it('should handle URL file addition', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} allowUrls={true} {...mockCallbacks} />)
      
      const urlInput = screen.getByPlaceholderText('Enter file URL')
      const addButton = screen.getByText('Add URL')
      
      await user.type(urlInput, 'https://example.com/image.png')
      await user.click(addButton)
      
      expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith([
        expect.objectContaining({
          name: 'image.png',
          url: 'https://example.com/image.png',
          isUrl: true,
        }),
      ])
    })

    it('should validate URL format', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} allowUrls={true} {...mockCallbacks} />)
      
      const urlInput = screen.getByPlaceholderText('Enter file URL')
      const addButton = screen.getByText('Add URL')
      
      await user.type(urlInput, 'invalid-url')
      await user.click(addButton)
      
      expect(screen.getByText('Please enter a valid URL')).toBeInTheDocument()
      expect(mockCallbacks.onFilesChange).not.toHaveBeenCalled()
    })

    it('should handle custom display name for URLs', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} allowUrls={true} {...mockCallbacks} />)
      
      const urlInput = screen.getByPlaceholderText('Enter file URL')
      const nameInput = screen.getByPlaceholderText('Display name (optional)')
      const addButton = screen.getByText('Add URL')
      
      await user.type(urlInput, 'https://example.com/image.png')
      await user.type(nameInput, 'Custom Image Name')
      await user.click(addButton)
      
      expect(mockCallbacks.onFilesChange).toHaveBeenCalledWith([
        expect.objectContaining({
          name: 'Custom Image Name',
          url: 'https://example.com/image.png',
          isUrl: true,
        }),
      ])
    })
  })

  describe('Upload Progress', () => {
    it('should show upload progress bar when uploading', () => {
      render(<FileUpload {...defaultProps} uploadProgress={45} />)
      
      const progressBar = screen.getByRole('progressbar')
      expect(progressBar).toHaveAttribute('aria-valuenow', '45')
      expect(screen.getByText('Uploading... 45%')).toBeInTheDocument()
    })

    it('should hide upload controls during upload', () => {
      render(<FileUpload {...defaultProps} uploadProgress={45} {...mockCallbacks} />)
      
      const uploadButton = screen.queryByText('Upload Files')
      expect(uploadButton).toBeDisabled()
    })
  })

  describe('Error Handling', () => {
    it('should display error messages', () => {
      render(<FileUpload {...defaultProps} error="Upload failed. Please try again." />)
      
      expect(screen.getByText('Upload failed. Please try again.')).toBeInTheDocument()
    })

    it('should clear errors when new files are selected', async () => {
      const user = userEvent.setup()
      const { rerender } = render(
        <FileUpload {...defaultProps} error="Upload failed" {...mockCallbacks} />
      )
      
      expect(screen.getByText('Upload failed')).toBeInTheDocument()
      
      // Rerender without error
      rerender(<FileUpload {...defaultProps} {...mockCallbacks} />)
      
      const fileInput = screen.getByTestId('file-input')
      const testFile = createMockFile('test.png', 'image/png')
      
      await user.upload(fileInput, testFile)
      
      expect(screen.queryByText('Upload failed')).not.toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('should have proper ARIA labels', () => {
      render(<FileUpload {...defaultProps} />)
      
      const fileInput = screen.getByTestId('file-input')
      expect(fileInput).toHaveAttribute('aria-label', 'File upload')
      
      const uploadArea = screen.getByTestId('file-upload-area')
      expect(uploadArea).toHaveAttribute('role', 'button')
      expect(uploadArea).toHaveAttribute('tabIndex', '0')
    })

    it('should be keyboard accessible', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      const fileInput = screen.getByTestId('file-input')
      
      // Focus and press Enter
      uploadArea.focus()
      expect(uploadArea).toHaveFocus()
      
      const clickSpy = jest.spyOn(fileInput, 'click')
      await user.keyboard('{Enter}')
      
      expect(clickSpy).toHaveBeenCalled()
    })

    it('should support Space key activation', async () => {
      const user = userEvent.setup()
      render(<FileUpload {...defaultProps} />)
      
      const uploadArea = screen.getByTestId('file-upload-area')
      const fileInput = screen.getByTestId('file-input')
      
      uploadArea.focus()
      const clickSpy = jest.spyOn(fileInput, 'click')
      await user.keyboard(' ')
      
      expect(clickSpy).toHaveBeenCalled()
    })
  })

  describe('File Size Formatting', () => {
    it('should format file sizes correctly', () => {
      const testFiles = [
        createMockFile('small.png', 'image/png', 512), // 512 B
        createMockFile('medium.png', 'image/png', 1536), // 1.5 KB
        createMockFile('large.png', 'image/png', 1048576), // 1 MB
      ]
      
      render(<FileUpload {...defaultProps} value={testFiles} />)
      
      expect(screen.getByText('512 Bytes')).toBeInTheDocument()
      expect(screen.getByText('1.5 KB')).toBeInTheDocument()
      expect(screen.getByText('1 MB')).toBeInTheDocument()
    })
  })
})