/**
 * @jest-environment jsdom
 */

import { storageService } from '@/services/storage'

// Mock localStorage
const mockLocalStorage = (() => {
  let store: Record<string, string> = {}

  return {
    getItem: jest.fn((key: string) => store[key] || null),
    setItem: jest.fn((key: string, value: string) => {
      store[key] = value
    }),
    removeItem: jest.fn((key: string) => {
      delete store[key]
    }),
    clear: jest.fn(() => {
      store = {}
    }),
    get length() {
      return Object.keys(store).length
    },
    key: jest.fn((index: number) => Object.keys(store)[index] || null),
  }
})()

// Mock sessionStorage
const mockSessionStorage = (() => {
  let store: Record<string, string> = {}

  return {
    getItem: jest.fn((key: string) => store[key] || null),
    setItem: jest.fn((key: string, value: string) => {
      store[key] = value
    }),
    removeItem: jest.fn((key: string) => {
      delete store[key]
    }),
    clear: jest.fn(() => {
      store = {}
    }),
    get length() {
      return Object.keys(store).length
    },
    key: jest.fn((index: number) => Object.keys(store)[index] || null),
  }
})()

Object.defineProperty(window, 'localStorage', {
  value: mockLocalStorage,
})

Object.defineProperty(window, 'sessionStorage', {
  value: mockSessionStorage,
})

describe('StorageService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockLocalStorage.clear()
    mockSessionStorage.clear()
  })

  describe('setLocal', () => {
    it('should store string values in localStorage', () => {
      storageService.setLocal('test-key', 'test-value')

      expect(mockLocalStorage.setItem).toHaveBeenCalledWith('test-key', '"test-value"')
    })

    it('should store object values in localStorage', () => {
      const testObject = { id: 1, name: 'test' }
      storageService.setLocal('test-object', testObject)

      expect(mockLocalStorage.setItem).toHaveBeenCalledWith(
        'test-object',
        JSON.stringify(testObject)
      )
    })

    it('should store array values in localStorage', () => {
      const testArray = [1, 2, 3]
      storageService.setLocal('test-array', testArray)

      expect(mockLocalStorage.setItem).toHaveBeenCalledWith(
        'test-array',
        JSON.stringify(testArray)
      )
    })

    it('should handle storage errors gracefully', () => {
      mockLocalStorage.setItem.mockImplementationOnce(() => {
        throw new Error('Storage quota exceeded')
      })

      expect(() => {
        storageService.setLocal('test-key', 'test-value')
      }).not.toThrow()
    })
  })

  describe('getLocal', () => {
    it('should retrieve and parse stored values from localStorage', () => {
      const testData = { id: 1, name: 'test' }
      mockLocalStorage.getItem.mockReturnValue(JSON.stringify(testData))

      const result = storageService.getLocal('test-key')

      expect(mockLocalStorage.getItem).toHaveBeenCalledWith('test-key')
      expect(result).toEqual(testData)
    })

    it('should return null for non-existent keys', () => {
      mockLocalStorage.getItem.mockReturnValue(null)

      const result = storageService.getLocal('non-existent-key')

      expect(result).toBeNull()
    })

    it('should return default value for non-existent keys', () => {
      mockLocalStorage.getItem.mockReturnValue(null)
      const defaultValue = { default: true }

      const result = storageService.getLocal('non-existent-key', defaultValue)

      expect(result).toEqual(defaultValue)
    })

    it('should handle JSON parsing errors gracefully', () => {
      mockLocalStorage.getItem.mockReturnValue('invalid-json{')

      const result = storageService.getLocal('corrupted-key')

      expect(result).toBeNull()
    })
  })

  describe('removeLocal', () => {
    it('should remove items from localStorage', () => {
      storageService.removeLocal('test-key')

      expect(mockLocalStorage.removeItem).toHaveBeenCalledWith('test-key')
    })
  })

  describe('clearLocal', () => {
    it('should clear all localStorage items', () => {
      storageService.clearLocal()

      expect(mockLocalStorage.clear).toHaveBeenCalled()
    })
  })

  describe('session storage methods', () => {
    it('should store values in sessionStorage', () => {
      storageService.setSession('session-key', 'session-value')

      expect(mockSessionStorage.setItem).toHaveBeenCalledWith(
        'session-key',
        '"session-value"'
      )
    })

    it('should retrieve values from sessionStorage', () => {
      mockSessionStorage.getItem.mockReturnValue('"session-value"')

      const result = storageService.getSession('session-key')

      expect(mockSessionStorage.getItem).toHaveBeenCalledWith('session-key')
      expect(result).toBe('session-value')
    })

    it('should remove values from sessionStorage', () => {
      storageService.removeSession('session-key')

      expect(mockSessionStorage.removeItem).toHaveBeenCalledWith('session-key')
    })

    it('should clear all sessionStorage items', () => {
      storageService.clearSession()

      expect(mockSessionStorage.clear).toHaveBeenCalled()
    })
  })

  describe('storage availability checks', () => {
    it('should handle storage errors gracefully', () => {
      mockLocalStorage.getItem.mockImplementation(() => {
        throw new Error('Storage not available')
      })

      const result = storageService.getLocal('test-key')

      expect(result).toBeNull()
    })

    it('should handle SSR environment', () => {
      // Simulate SSR environment
      const originalWindow = global.window
      delete (global as any).window

      const result = storageService.getLocal('test-key', 'default')

      expect(result).toBe('default')

      // Restore window
      global.window = originalWindow
    })
  })


})