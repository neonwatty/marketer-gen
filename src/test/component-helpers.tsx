import React from 'react'
import { vi } from 'vitest'
import type { FileWithPreview } from '@/components/ui/file-upload'

// Mock implementations for complex components
export const mockFileUploadHandlers = {
  onFilesChange: vi.fn(),
  onUpload: vi.fn().mockResolvedValue(undefined),
}

export const mockFormHandlers = {
  onSubmit: vi.fn(),
  onError: vi.fn(),
  onReset: vi.fn(),
}

// File upload testing patterns
export function createFileWithPreview(
  name: string,
  type: string,
  size: number,
  uploadStatus: 'pending' | 'uploading' | 'success' | 'error' = 'pending'
): FileWithPreview {
  const file = new File(['test content'], name, { type })
  Object.defineProperty(file, 'size', { value: size })

  return Object.assign(file, {
    id: Math.random().toString(36).substring(7),
    preview: type.startsWith('image/') ? 'blob:mock-preview-url' : undefined,
    uploadProgress: uploadStatus === 'success' ? 100 : 0,
    uploadStatus,
    error: uploadStatus === 'error' ? 'Upload failed' : undefined,
  })
}

export function createFileList(files: File[]): FileList {
  const fileList = {
    length: files.length,
    item: (index: number) => files[index] || null,
    [Symbol.iterator]: function* () {
      yield* files
    },
  } as FileList

  Object.defineProperty(fileList, 'length', { value: files.length })
  return fileList
}

// Form field testing patterns
export const commonFormFields = {
  email: {
    valid: ['user@example.com', 'test.user+tag@domain.co.uk'],
    invalid: ['invalid-email', '@domain.com', 'user@', 'user.domain.com'],
  },
  password: {
    valid: ['Password123!', 'MySecure@Pass1', 'Complex$Password9'],
    invalid: [
      'short', // too short
      'lowercase123!', // no uppercase
      'UPPERCASE123!', // no lowercase
      'NoNumbers!', // no numbers
      'NoSpecialChars123', // no special characters
    ],
  },
  url: {
    valid: ['https://example.com', 'http://localhost:3000', 'https://sub.domain.co.uk/path'],
    invalid: ['not-a-url', 'ftp://example.com', 'example.com'],
  },
  phone: {
    valid: ['+1 234 567 8900', '(234) 567-8900', '234-567-8900', '2345678900'],
    invalid: ['123', 'abc-def-ghij', '1-800-FLOWERS'],
  },
}

// Sidebar testing helpers
export function mockSidebarContext(isOpen: boolean = true) {
  return {
    state: isOpen ? 'expanded' : 'collapsed',
    open: isOpen,
    setOpen: vi.fn(),
    openMobile: false,
    setOpenMobile: vi.fn(),
    isMobile: false,
    toggleSidebar: vi.fn(),
  }
}

// Layout testing patterns
export function mockLayoutProps() {
  return {
    children: <div data-testid="layout-content">Test Content</div>,
  }
}

// Responsive design testing utilities
export function mockMediaQuery(matches: boolean) {
  const mockMediaQuery = {
    matches,
    media: '',
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  }

  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation(() => mockMediaQuery),
  })

  return mockMediaQuery
}

// Validation schema testing patterns
export const validationTestCases = {
  contentGeneration: {
    valid: {
      title: 'Marketing Campaign Title',
      description: 'This is a comprehensive description of our marketing campaign that meets the minimum character requirements.',
      contentType: 'blog-post' as const,
      targetAudience: 'professionals',
      tone: 'professional' as const,
      keywords: ['marketing', 'campaign'],
    },
    invalid: {
      titleTooShort: { title: '' },
      titleTooLong: { title: 'a'.repeat(201) },
      descriptionTooShort: { description: 'short' },
      descriptionTooLong: { description: 'a'.repeat(1001) },
      invalidContentType: { contentType: 'invalid-type' },
    },
  },
  campaign: {
    valid: {
      name: 'Summer Campaign 2024',
      description: 'A comprehensive summer marketing campaign',
      startDate: new Date('2024-06-01'),
      endDate: new Date('2024-08-31'),
      budget: 10000,
      status: 'draft' as const,
    },
    invalid: {
      nameTooLong: { name: 'a'.repeat(101) },
      negitiveBudget: { budget: -1000 },
      endBeforeStart: {
        startDate: new Date('2024-08-31'),
        endDate: new Date('2024-06-01'),
      },
    },
  },
}

// Mock API responses
export const mockApiResponses = {
  uploadSuccess: {
    status: 'success',
    files: [
      {
        id: '1',
        filename: 'test-image.jpg',
        url: 'https://example.com/uploads/test-image.jpg',
        size: 50000,
        type: 'image/jpeg',
      },
    ],
  },
  uploadError: {
    status: 'error',
    message: 'Upload failed: File too large',
    errors: [
      {
        field: 'file',
        message: 'File size exceeds maximum allowed',
      },
    ],
  },
  formValidationError: {
    status: 'error',
    message: 'Validation failed',
    errors: [
      { field: 'email', message: 'Please enter a valid email address' },
      { field: 'password', message: 'Password must be at least 8 characters' },
    ],
  },
}

// Performance testing helpers
// File creation helpers
export function createMockImageFile(
  name: string = 'test-image.jpg',
  size: number = 50000
): File {
  // Determine MIME type from file extension
  const extension = name.split('.').pop()?.toLowerCase()
  let mimeType = 'image/jpeg' // default
  
  switch (extension) {
    case 'png':
      mimeType = 'image/png'
      break
    case 'gif':
      mimeType = 'image/gif'
      break
    case 'webp':
      mimeType = 'image/webp'
      break
    case 'svg':
      mimeType = 'image/svg+xml'
      break
    case 'jpg':
    case 'jpeg':
    default:
      mimeType = 'image/jpeg'
      break
  }
  
  const file = new File(['mock image content'], name, { type: mimeType })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

export function createMockPdfFile(
  name: string = 'test-document.pdf',
  size: number = 100000
): File {
  const file = new File(['mock pdf content'], name, { type: 'application/pdf' })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

export function createMockVideoFile(
  name: string = 'test-video.mp4',
  size: number = 5000000
): File {
  const file = new File(['mock video content'], name, { type: 'video/mp4' })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

export function createLargeFile(sizeInMB: number): File {
  const size = sizeInMB * 1024 * 1024
  const content = 'x'.repeat(size)
  const file = new File([content], `large-file-${sizeInMB}mb.txt`, { type: 'text/plain' })
  Object.defineProperty(file, 'size', { value: size })
  return file
}

export function simulateSlowNetwork(delay: number = 2000) {
  return new Promise(resolve => setTimeout(resolve, delay))
}

// Error boundary testing
export function createErrorThrowingComponent(errorMessage: string = 'Test error') {
  return function ErrorComponent() {
    throw new Error(errorMessage)
  }
}

// Custom hooks testing helpers
export function createMockFormMethods<T>() {
  return {
    register: vi.fn(),
    handleSubmit: vi.fn(),
    formState: {
      errors: {},
      isValid: true,
      isSubmitting: false,
      isDirty: false,
      touchedFields: {},
    },
    getValues: vi.fn(),
    setValue: vi.fn(),
    trigger: vi.fn(),
    reset: vi.fn(),
    watch: vi.fn(),
    control: {} as any,
  }
}

// Component state testing patterns
export const componentStates = {
  loading: { isLoading: true, error: null, data: null },
  error: { isLoading: false, error: new Error('Test error'), data: null },
  success: { isLoading: false, error: null, data: { id: 1, name: 'Test' } },
  empty: { isLoading: false, error: null, data: [] },
}