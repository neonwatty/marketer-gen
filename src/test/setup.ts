import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn(() => ({
  observe: vi.fn(),
  disconnect: vi.fn(),
  unobserve: vi.fn(),
}))

// Mock ResizeObserver 
global.ResizeObserver = vi.fn(() => ({
  observe: vi.fn(),
  disconnect: vi.fn(),
  unobserve: vi.fn(),
}))

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(), // Deprecated
    removeListener: vi.fn(), // Deprecated
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// Mock URL.createObjectURL and revokeObjectURL for file upload tests
global.URL.createObjectURL = vi.fn(() => 'mocked-url')
global.URL.revokeObjectURL = vi.fn()

// Mock File constructor for file upload tests
global.File = class File {
  name: string
  size: number
  type: string
  lastModified: number
  webkitRelativePath: string

  constructor(fileBits: BlobPart[], fileName: string, options: FilePropertyBag = {}) {
    this.name = fileName
    this.size = fileBits.reduce((size, bit) => {
      if (typeof bit === 'string') return size + bit.length
      if (bit instanceof ArrayBuffer) return size + bit.byteLength
      return size + (bit as Blob).size
    }, 0)
    this.type = options.type || ''
    this.lastModified = options.lastModified || Date.now()
    this.webkitRelativePath = ''
  }

  text() {
    return Promise.resolve('')
  }

  arrayBuffer() {
    return Promise.resolve(new ArrayBuffer(0))
  }

  stream() {
    return new ReadableStream()
  }

  slice() {
    return new Blob()
  }
}

// Mock DataTransfer for drag and drop tests
global.DataTransfer = class DataTransfer {
  dropEffect: string = 'none'
  effectAllowed: string = 'all'
  files: FileList = {
    length: 0,
    item: () => null,
    [Symbol.iterator]: function* () {},
  } as FileList
  items: DataTransferItemList = {
    length: 0,
    add: vi.fn(),
    clear: vi.fn(),
    remove: vi.fn(),
    [Symbol.iterator]: function* () {},
  } as DataTransferItemList
  types: string[] = []

  clearData() {}
  getData() { return '' }
  setData() {}
  setDragImage() {}
}

// Mock clipboard for potential future clipboard tests (only if not already defined)
if (!navigator.clipboard) {
  Object.defineProperty(navigator, 'clipboard', {
    writable: true,
    value: {
      writeText: vi.fn().mockResolvedValue(undefined),
      readText: vi.fn().mockResolvedValue(''),
    },
  })
}

// Suppress console errors in tests unless debugging
const originalConsoleError = console.error
beforeAll(() => {
  console.error = vi.fn()
})

afterAll(() => {
  console.error = originalConsoleError
})

// Clean up after each test
afterEach(() => {
  vi.clearAllMocks()
})