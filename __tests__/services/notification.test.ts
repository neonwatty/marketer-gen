/**
 * @jest-environment jsdom
 */

import { notificationService } from '@/services/notification'

// Mock console methods for development logging
const originalConsoleLog = console.log
const originalConsoleError = console.error

beforeEach(() => {
  console.log = jest.fn()
  console.error = jest.fn()
})

afterEach(() => {
  console.log = originalConsoleLog
  console.error = originalConsoleError
})

describe('NotificationService', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('showNotification', () => {
    it('should show success notification', () => {
      const options = {
        title: 'Success',
        message: 'Operation completed successfully',
        type: 'success' as const
      }
      
      notificationService.showNotification(options)

      // In development, should log to console
      expect(console.log).toHaveBeenCalledWith(expect.stringContaining('Success'))
    })

    it('should show error notification', () => {
      const options = {
        title: 'Error',
        message: 'Something went wrong',
        type: 'error' as const
      }
      
      notificationService.showNotification(options)

      expect(console.error).toHaveBeenCalledWith(expect.stringContaining('Error'))
    })

    it('should handle notification with actions', () => {
      const mockAction = jest.fn()
      const options = {
        title: 'Action Required',
        message: 'Please confirm this action',
        type: 'warning' as const,
        actions: [{ label: 'Confirm', action: mockAction }]
      }
      
      notificationService.showNotification(options)

      expect(console.log).toHaveBeenCalledWith(expect.stringContaining('Action Required'))
    })
  })

  describe('requestPermission', () => {
    it('should request notification permission', async () => {
      // Mock Notification API
      Object.defineProperty(window, 'Notification', {
        value: {
          permission: 'default',
          requestPermission: jest.fn().mockResolvedValue('granted'),
        },
        configurable: true,
      })

      const result = await notificationService.requestPermission()

      expect(window.Notification.requestPermission).toHaveBeenCalled()
      expect(result).toBe('granted')
    })

    it('should handle permission already granted', async () => {
      Object.defineProperty(window, 'Notification', {
        value: {
          permission: 'granted',
          requestPermission: jest.fn(),
        },
        configurable: true,
      })

      const result = await notificationService.requestPermission()

      expect(window.Notification.requestPermission).not.toHaveBeenCalled()
      expect(result).toBe('granted')
    })

    it('should handle unsupported browsers', async () => {
      delete (window as any).Notification

      const result = await notificationService.requestPermission()

      expect(result).toBe('denied')
    })
  })

  describe('showPushNotification', () => {
    it('should show push notification when permission granted', () => {
      const mockNotification = jest.fn()
      Object.defineProperty(window, 'Notification', {
        value: mockNotification,
        configurable: true,
      })
      Object.defineProperty(window.Notification, 'permission', {
        value: 'granted',
        configurable: true,
      })

      const options = {
        title: 'Test Notification',
        body: 'This is a test',
        icon: '/icon.png'
      }

      notificationService.showPushNotification(options)

      expect(mockNotification).toHaveBeenCalledWith('Test Notification', {
        body: 'This is a test',
        icon: '/icon.png',
        badge: '/badge-72x72.png',
        tag: undefined,
        data: undefined,
      })
    })

    it('should not show notification when permission denied', () => {
      const mockNotification = jest.fn()
      Object.defineProperty(window, 'Notification', {
        value: mockNotification,
        configurable: true,
      })
      Object.defineProperty(window.Notification, 'permission', {
        value: 'denied',
        configurable: true,
      })

      const options = {
        title: 'Test Notification',
        body: 'This is a test'
      }

      notificationService.showPushNotification(options)

      expect(mockNotification).not.toHaveBeenCalled()
    })
  })

  describe('clearAll', () => {
    it('should clear all notifications', () => {
      notificationService.clearAll()

      // Should log clearing action in development
      expect(console.log).toHaveBeenCalledWith('Clearing all notifications')
    })
  })
})