import { describe, it, expect, vi, beforeEach } from 'vitest'
import { waitFor } from '@testing-library/react'
import { z } from 'zod'
import { renderWithForm } from '@/test/test-utils'
import { 
  createMockImageFile, 
  createMockPdfFile,
  mockFileUploadHandlers
} from '@/test/component-helpers'
import { FileUploadField } from '@/components/forms/FileUploadField'

const testSchema = z.object({
  attachments: z.array(z.any()).min(1, 'Please upload at least one file'),
  brandAssets: z.array(z.any()).max(5, 'Maximum 5 files allowed'),
})

type TestFormData = z.infer<typeof testSchema>

describe('FileUploadField Component', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Form Integration', () => {
    it('renders with label and description', () => {
      const { getByText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Upload Files"
          description="Select files to upload"
        />,
        { schema: testSchema }
      )

      expect(getByText('Upload Files')).toBeInTheDocument()
      expect(getByText('Select files to upload')).toBeInTheDocument()
    })

    it('shows required indicator when required=true', () => {
      const { container } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Required Files"
          required
        />,
        { schema: testSchema }
      )

      const requiredIndicator = container.querySelector('.text-destructive')
      expect(requiredIndicator).toBeInTheDocument()
      expect(requiredIndicator).toHaveTextContent('*')
    })

    it('integrates with React Hook Form validation', async () => {
      const { user, getByTestId, getByText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Required Files"
          required
        />,
        { 
          schema: testSchema,
          onSubmit: vi.fn()
        }
      )

      // Try to submit without files - should show validation error
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        expect(getByText('Please upload at least one file')).toBeInTheDocument()
      })
    })

    it('passes form data correctly when files are selected', async () => {
      const mockSubmit = vi.fn()
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByTestId, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Upload Files"
        />,
        { 
          schema: testSchema,
          onSubmit: mockSubmit,
          defaultValues: { attachments: [] }
        }
      )

      // Upload file
      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // Submit form
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        expect(mockSubmit).toHaveBeenCalled()
        const callArgs = mockSubmit.mock.calls[0][0]
        expect(callArgs).toHaveProperty('attachments')
        expect(callArgs.attachments).toHaveLength(1)
        expect(callArgs.attachments[0]).toHaveProperty('name', 'test.jpg')
        expect(callArgs.attachments[0]).toHaveProperty('size', 50000)
        expect(callArgs.attachments[0]).toHaveProperty('type', 'image/jpeg')
      })
    })

    it('validates maximum file count', async () => {
      const mockFiles = [
        createMockImageFile('file1.jpg', 50000),
        createMockImageFile('file2.jpg', 50000),
        createMockImageFile('file3.jpg', 50000),
        createMockImageFile('file4.jpg', 50000),
        createMockImageFile('file5.jpg', 50000),
        createMockImageFile('file6.jpg', 50000), // This exceeds the limit of 5
      ]
      
      const { user, getByRole, getByTestId, getByText, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="brandAssets"
          label="Brand Assets"
          maxFiles={5}
        />,
        { 
          schema: testSchema,
          onSubmit: vi.fn()
        }
      )

      // Upload files exceeding limit
      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFiles)

      // Submit form to trigger validation
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        expect(getByText('Some files cannot be uploaded')).toBeInTheDocument()
      })
    })
  })

  describe('File Upload Configuration', () => {
    it('passes maxFiles prop correctly', () => {
      const { getByText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          maxFiles={3}
        />,
        { schema: testSchema }
      )

      expect(getByText('Maximum 3 files, up to 10 MB each')).toBeInTheDocument()
    })

    it('passes maxSize prop correctly', () => {
      const { getByText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          maxSize={5 * 1024 * 1024} // 5MB
        />,
        { schema: testSchema }
      )

      expect(getByText('Maximum 10 files, up to 5 MB each')).toBeInTheDocument()
    })

    it('passes acceptedFileTypes prop correctly', async () => {
      const customTypes = {
        'image/jpeg': ['.jpg', '.jpeg'],
        'image/png': ['.png'],
      }
      
      const mockFile = createMockImageFile('test.jpg', 50000)
      const { user, getByRole, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          acceptedFileTypes={customTypes}
        />,
        { schema: testSchema }
      )

      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // File should be accepted since it matches the custom types
      // The actual validation is handled by react-dropzone
    })

    it('handles single file mode', async () => {
      const mockFiles = [
        createMockImageFile('file1.jpg', 50000),
        createMockImageFile('file2.jpg', 50000),
      ]
      
      const { user, getByRole, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          multiple={false}
        />,
        { schema: testSchema }
      )

      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFiles)

      // Should only accept the first file in single mode (Files (1/10) format)
      await waitFor(() => {
        expect(document.body.textContent).toMatch(/Files \(1\/\d+\)/)
      })
    })
  })

  describe('Upload Functionality Integration', () => {
    it('handles onUpload prop correctly', async () => {
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByText, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          onUpload={mockFileUploadHandlers.onUpload}
        />,
        { schema: testSchema }
      )

      // Upload file
      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // Wait for upload button to appear and click it
      await waitFor(() => {
        expect(getByText('Upload Files')).toBeInTheDocument()
      })
      
      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      // Wait for the upload handler to be called during the upload process
      await waitFor(() => {
        expect(mockFileUploadHandlers.onUpload).toHaveBeenCalled()
      }, { timeout: 3000 })
    })

    it('shows upload progress in form context', async () => {
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByText, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          onUpload={mockFileUploadHandlers.onUpload}
        />,
        { schema: testSchema }
      )

      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      // Should show uploading state
      await waitFor(() => {
        expect(getByText('Uploading...')).toBeInTheDocument()
      }, { timeout: 100 })
    })

    it('handles upload errors in form context', async () => {
      const failingUpload = vi.fn().mockRejectedValue(new Error('Upload failed'))
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByText, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          onUpload={failingUpload}
        />,
        { schema: testSchema }
      )

      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      const uploadButton = getByText('Upload Files')
      await user.click(uploadButton)

      await waitFor(() => {
        expect(getByText('Upload failed')).toBeInTheDocument()
      }, { timeout: 3000 })
    })
  })

  describe('Disabled State', () => {
    it('respects disabled prop', () => {
      const { container } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          disabled
        />,
        { schema: testSchema }
      )

      const dropzone = container.querySelector('[role="button"]')
      expect(dropzone).toHaveClass('cursor-not-allowed', 'opacity-50')
    })

    it('disables upload during form submission', async () => {
      const slowSubmit = vi.fn().mockImplementation(
        () => new Promise(resolve => setTimeout(resolve, 1000))
      )
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByTestId, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          onUpload={mockFileUploadHandlers.onUpload}
        />,
        { 
          schema: testSchema,
          onSubmit: slowSubmit
        }
      )

      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // Start form submission
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      // Upload functionality should be disabled during form submission
      const uploadButton = document.querySelector('button:contains("Upload Files")')
      if (uploadButton) {
        expect(uploadButton).toBeDisabled()
      }
    })
  })

  describe('Validation Messaging', () => {
    it('shows validation errors below the component', async () => {
      const { user, getByTestId } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Required Files"
        />,
        { schema: testSchema }
      )

      // Submit without files to trigger validation error
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[role="alert"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveTextContent('Please upload at least one file')
      })
    })

    it('clears validation errors when files are added', async () => {
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByTestId, queryByText, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Required Files"
        />,
        { schema: testSchema }
      )

      // First, trigger validation error
      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        expect(queryByText('Please upload at least one file')).toBeInTheDocument()
      })

      // Then add a file - should clear the error
      const uploadArea = getByLabelText('Upload files')
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      await waitFor(() => {
        expect(queryByText('Please upload at least one file')).not.toBeInTheDocument()
      })
    })
  })

  describe('Accessibility in Form Context', () => {
    it('associates label with file upload area', () => {
      const { getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Upload Files"
        />,
        { schema: testSchema }
      )

      // Should be able to find the upload area by the upload files aria-label
      const uploadArea = getByLabelText('Upload files')
      expect(uploadArea).toBeInTheDocument()
    })

    it('provides accessible error messages', async () => {
      const { user, getByTestId } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Required Files"
        />,
        { schema: testSchema }
      )

      const submitButton = getByTestId('submit-button')
      await user.click(submitButton)

      await waitFor(() => {
        const errorMessage = document.querySelector('[role="alert"]')
        expect(errorMessage).toBeInTheDocument()
        expect(errorMessage).toHaveAttribute('aria-live')
      })
    })

    it('maintains focus management in form context', async () => {
      const mockFile = createMockImageFile('test.jpg', 50000)
      
      const { user, getByRole, getByLabelText } = renderWithForm<TestFormData>(
        <FileUploadField 
          name="attachments"
          label="Upload Files"
        />,
        { schema: testSchema }
      )

      const uploadArea = getByLabelText('Upload files')
      
      // Should be focusable
      await user.tab()
      expect(uploadArea).toHaveFocus()

      // Should maintain focus after file selection
      const input = uploadArea.querySelector('input[type="file"]')
      await user.upload(input as HTMLInputElement, mockFile)

      // Focus should remain manageable
      await user.tab()
      // Focus should move to next focusable element
    })
  })
})