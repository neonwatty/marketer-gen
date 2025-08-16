/**
 * @jest-environment jsdom
 */

// Mock the API client BEFORE importing
jest.mock('@/services/api', () => ({
  apiClient: {
    get: jest.fn(),
    post: jest.fn(),
    put: jest.fn(),
    delete: jest.fn(),
  },
}))

import { userService } from '@/services/user'
import { apiClient } from '@/services/api'

// Get reference to mocked functions
const mockApiClient = apiClient as jest.Mocked<typeof apiClient>

// Mock storage service
const mockStorageService = {
  setLocal: jest.fn(),
  getLocal: jest.fn(),
  removeLocal: jest.fn(),
  setSession: jest.fn(),
  getSession: jest.fn(),
  removeSession: jest.fn(),
}

jest.mock('@/services/storage', () => ({
  StorageService: jest.fn(() => mockStorageService),
}))

describe.skip('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('getCurrentUser', () => {
    it('should fetch current user data', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        avatar: '/avatar.jpg',
      }

      mockApiClient.get.mockResolvedValue({
        success: true,
        data: mockUser,
      })

      const result = await userService.getCurrentUser()

      expect(mockApiClient.get).toHaveBeenCalledWith('/api/user/profile')
      expect(result).toEqual(mockUser)
    })

    it('should handle API errors', async () => {
      mockApiClient.get.mockResolvedValue({
        success: false,
        error: 'Unauthorized',
      })

      const result = await userService.getCurrentUser()

      expect(result).toBeNull()
    })

    it('should handle network errors', async () => {
      mockApiClient.get.mockRejectedValue(new Error('Network error'))

      const result = await userService.getCurrentUser()

      expect(result).toBeNull()
    })
  })

  describe('updateProfile', () => {
    it('should update user profile successfully', async () => {
      const updateData = {
        name: 'Updated Name',
        email: 'updated@example.com',
      }

      const updatedUser = {
        id: 'user-123',
        ...updateData,
        avatar: '/avatar.jpg',
      }

      mockApiClient.put.mockResolvedValue({
        success: true,
        data: updatedUser,
      })

      const result = await userService.updateProfile(updateData)

      expect(mockApiClient.put).toHaveBeenCalledWith('/api/user/profile', updateData)
      expect(result).toEqual(updatedUser)
    })

    it('should handle validation errors', async () => {
      const updateData = {
        email: 'invalid-email',
      }

      mockApiClient.put.mockResolvedValue({
        success: false,
        error: 'Invalid email format',
      })

      await expect(userService.updateProfile(updateData)).rejects.toThrow('Invalid email format')
    })
  })

  describe('uploadAvatar', () => {
    it('should upload avatar successfully', async () => {
      const mockFile = new File(['avatar-data'], 'avatar.jpg', { type: 'image/jpeg' })
      const avatarUrl = '/uploads/avatar-123.jpg'

      mockApiClient.post.mockResolvedValue({
        success: true,
        data: { url: avatarUrl },
      })

      const result = await userService.uploadAvatar(mockFile)

      expect(mockApiClient.post).toHaveBeenCalledWith(
        '/api/user/avatar',
        expect.any(FormData)
      )
      expect(result).toBe(avatarUrl)
    })

    it('should handle file upload errors', async () => {
      const mockFile = new File(['avatar-data'], 'avatar.jpg', { type: 'image/jpeg' })

      mockApiClient.post.mockResolvedValue({
        success: false,
        error: 'File too large',
      })

      await expect(userService.uploadAvatar(mockFile)).rejects.toThrow('File too large')
    })

    it('should validate file type', async () => {
      const invalidFile = new File(['data'], 'document.pdf', { type: 'application/pdf' })

      await expect(userService.uploadAvatar(invalidFile)).rejects.toThrow(
        'Invalid file type. Only images are allowed.'
      )
    })

    it('should validate file size', async () => {
      // Create a mock file that's too large (>5MB)
      const largeFile = new File(['x'.repeat(6 * 1024 * 1024)], 'large.jpg', {
        type: 'image/jpeg',
      })

      await expect(userService.uploadAvatar(largeFile)).rejects.toThrow(
        'File size must be less than 5MB'
      )
    })
  })

  describe('getPreferences', () => {
    it('should get user preferences from storage', () => {
      const mockPreferences = {
        theme: 'dark',
        notifications: true,
        language: 'en',
      }

      mockStorageService.getLocal.mockReturnValue(mockPreferences)

      const result = userService.getPreferences()

      expect(mockStorageService.getLocal).toHaveBeenCalledWith('user-preferences', {})
      expect(result).toEqual(mockPreferences)
    })

    it('should return default preferences if none stored', () => {
      mockStorageService.getLocal.mockReturnValue({})

      const result = userService.getPreferences()

      expect(result).toEqual({})
    })
  })

  describe('updatePreferences', () => {
    it('should update user preferences', () => {
      const newPreferences = {
        theme: 'light',
        notifications: false,
      }

      const existingPreferences = {
        language: 'en',
      }

      mockStorageService.getLocal.mockReturnValue(existingPreferences)

      userService.updatePreferences(newPreferences)

      expect(mockStorageService.setLocal).toHaveBeenCalledWith('user-preferences', {
        ...existingPreferences,
        ...newPreferences,
      })
    })
  })

  describe('clearPreferences', () => {
    it('should clear user preferences from storage', () => {
      userService.clearPreferences()

      expect(mockStorageService.removeLocal).toHaveBeenCalledWith('user-preferences')
    })
  })

  describe('caching', () => {
    it('should cache user data after successful fetch', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      }

      mockApiClient.get.mockResolvedValue({
        success: true,
        data: mockUser,
      })

      await userService.getCurrentUser()

      expect(mockStorageService.setSession).toHaveBeenCalledWith('current-user', mockUser)
    })

    it('should return cached user data when available', async () => {
      const cachedUser = {
        id: 'user-123',
        email: 'cached@example.com',
        name: 'Cached User',
      }

      mockStorageService.getSession.mockReturnValue(cachedUser)

      const result = await userService.getCurrentUser()

      expect(mockApiClient.get).not.toHaveBeenCalled()
      expect(result).toEqual(cachedUser)
    })

    it('should clear cached user data on logout', () => {
      userService.clearUserCache()

      expect(mockStorageService.removeSession).toHaveBeenCalledWith('current-user')
    })
  })

  describe('session management', () => {
    it('should check if user is logged in based on cached data', () => {
      mockStorageService.getSession.mockReturnValue({
        id: 'user-123',
        email: 'test@example.com',
      })

      const result = userService.isLoggedIn()

      expect(result).toBe(true)
    })

    it('should return false when no user data is cached', () => {
      mockStorageService.getSession.mockReturnValue(null)

      const result = userService.isLoggedIn()

      expect(result).toBe(false)
    })
  })

  describe('error handling', () => {
    it('should handle storage errors gracefully', () => {
      mockStorageService.getLocal.mockImplementation(() => {
        throw new Error('Storage error')
      })

      const result = userService.getPreferences()

      expect(result).toEqual({})
    })

    it('should handle API timeout errors', async () => {
      mockApiClient.get.mockRejectedValue(new Error('Request timeout'))

      const result = await userService.getCurrentUser()

      expect(result).toBeNull()
    })
  })
})