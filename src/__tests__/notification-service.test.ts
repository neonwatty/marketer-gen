import { PrismaClient, NotificationType, NotificationCategory, NotificationPriority, NotificationStatus, NotificationChannel, EmailFrequency } from '@prisma/client'
import { 
  NotificationService, 
  NotificationData, 
  NotificationPreferences 
} from '@/lib/notifications/notification-service'
import { nanoid } from 'nanoid'
import { vi } from 'vitest'

// Mock dependencies
vi.mock('nanoid', () => ({
  nanoid: vi.fn(() => 'test-notification-id-123')
}))

const mockPrismaClient = {
  notification: {
    create: vi.fn(),
    findMany: vi.fn(),
    findFirst: vi.fn(),
    findUnique: vi.fn(),
    update: vi.fn(),
    updateMany: vi.fn(),
    delete: vi.fn(),
    deleteMany: vi.fn(),
    count: vi.fn(),
    groupBy: vi.fn()
  },
  notificationPreference: {
    findUnique: vi.fn(),
    upsert: vi.fn(),
    create: vi.fn(),
    update: vi.fn()
  },
  notificationBatch: {
    create: vi.fn(),
    findMany: vi.fn(),
    update: vi.fn()
  },
  user: {
    findUnique: vi.fn(),
    findMany: vi.fn()
  }
} as unknown as PrismaClient

// Mock email service
const mockEmailService = {
  sendEmail: vi.fn(),
  sendBulkEmails: vi.fn(),
  sendDigestEmail: vi.fn()
}

// Mock push service
const mockPushService = {
  sendPush: vi.fn(),
  sendBulkPush: vi.fn()
}

describe('NotificationService', () => {
  let notificationService: NotificationService

  beforeEach(() => {
    vi.clearAllMocks()
    notificationService = new NotificationService(
      mockPrismaClient,
      mockEmailService,
      mockPushService
    )
  })

  describe('Initialization', () => {
    test('should initialize with required dependencies', () => {
      expect(notificationService).toBeInstanceOf(NotificationService)
    })

    test('should initialize without optional services', () => {
      const service = new NotificationService(mockPrismaClient)
      expect(service).toBeInstanceOf(NotificationService)
    })
  })

  describe('Basic Notification Creation', () => {
    test('should create a simple notification', async () => {
      const notificationData: NotificationData = {
        type: NotificationType.APPROVAL_REQUEST,
        category: NotificationCategory.WORKFLOW,
        title: 'Approval Required',
        message: 'Please approve the campaign content',
        recipientId: 'user-123',
        senderId: 'user-456',
        entityType: 'campaign',
        entityId: 'campaign-789'
      }

      mockPrismaClient.notification.create.mockResolvedValueOnce({
        id: 'test-notification-id-123',
        ...notificationData,
        status: NotificationStatus.PENDING,
        createdAt: new Date(),
        updatedAt: new Date()
      })

      const result = await notificationService.createNotification(notificationData)

      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: {
          id: 'test-notification-id-123',
          type: NotificationType.APPROVAL_REQUEST,
          category: NotificationCategory.WORKFLOW,
          priority: NotificationPriority.MEDIUM, // Default
          title: 'Approval Required',
          message: 'Please approve the campaign content',
          recipientId: 'user-123',
          senderId: 'user-456',
          entityType: 'campaign',
          entityId: 'campaign-789',
          status: NotificationStatus.PENDING,
          channels: expect.any(String), // JSON string
          metadata: null
        }
      })

      expect(result.id).toBe('test-notification-id-123')
    })

    test('should create notification with custom priority and channels', async () => {
      const notificationData: NotificationData = {
        type: NotificationType.SYSTEM_ALERT,
        category: NotificationCategory.SYSTEM,
        priority: NotificationPriority.HIGH,
        title: 'System Alert',
        message: 'High resource usage detected',
        recipientId: 'admin-user',
        channels: {
          inApp: true,
          email: true,
          push: true,
          desktop: false
        },
        metadata: {
          severity: 'high',
          resourceType: 'cpu',
          threshold: 90
        }
      }

      await notificationService.createNotification(notificationData)

      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          priority: NotificationPriority.HIGH,
          channels: JSON.stringify({
            inApp: true,
            email: true,
            push: true,
            desktop: false
          }),
          metadata: JSON.stringify({
            severity: 'high',
            resourceType: 'cpu',
            threshold: 90
          })
        })
      })
    })

    test('should create notification with expiration', async () => {
      const expirationDate = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
      
      const notificationData: NotificationData = {
        type: NotificationType.REMINDER,
        category: NotificationCategory.GENERAL,
        title: 'Campaign Deadline Reminder',
        message: 'Your campaign expires tomorrow',
        recipientId: 'user-123',
        expiresAt: expirationDate
      }

      await notificationService.createNotification(notificationData)

      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          expiresAt: expirationDate
        })
      })
    })
  })

  describe('Bulk Notification Creation', () => {
    test('should create multiple notifications at once', async () => {
      const notifications: NotificationData[] = [
        {
          type: NotificationType.MENTION,
          category: NotificationCategory.SOCIAL,
          title: 'You were mentioned',
          message: 'John mentioned you in a comment',
          recipientId: 'user-1'
        },
        {
          type: NotificationType.MENTION,
          category: NotificationCategory.SOCIAL,
          title: 'You were mentioned',
          message: 'John mentioned you in a comment',
          recipientId: 'user-2'
        }
      ]

      mockPrismaClient.notification.create
        .mockResolvedValueOnce({ id: 'notification-1' })
        .mockResolvedValueOnce({ id: 'notification-2' })

      const results = await notificationService.createBulkNotifications(notifications)

      expect(results).toHaveLength(2)
      expect(mockPrismaClient.notification.create).toHaveBeenCalledTimes(2)
    })

    test('should handle partial failures in bulk creation', async () => {
      const notifications: NotificationData[] = [
        {
          type: NotificationType.COMMENT,
          category: NotificationCategory.SOCIAL,
          title: 'New comment',
          message: 'Someone commented on your post',
          recipientId: 'user-1'
        },
        {
          type: NotificationType.COMMENT,
          category: NotificationCategory.SOCIAL,
          title: 'New comment',
          message: 'Someone commented on your post',
          recipientId: 'invalid-user'
        }
      ]

      mockPrismaClient.notification.create
        .mockResolvedValueOnce({ id: 'notification-1' })
        .mockRejectedValueOnce(new Error('User not found'))

      const results = await notificationService.createBulkNotifications(notifications, {
        continueOnError: true
      })

      expect(results).toHaveLength(1)
      expect(results[0].id).toBe('notification-1')
    })

    test('should group similar notifications', async () => {
      const notifications: NotificationData[] = [
        {
          type: NotificationType.LIKE,
          category: NotificationCategory.SOCIAL,
          title: 'New like',
          message: 'Alice liked your post',
          recipientId: 'user-1',
          groupKey: 'likes-post-123'
        },
        {
          type: NotificationType.LIKE,
          category: NotificationCategory.SOCIAL,
          title: 'New like',
          message: 'Bob liked your post',
          recipientId: 'user-1',
          groupKey: 'likes-post-123'
        }
      ]

      await notificationService.createBulkNotifications(notifications, {
        enableGrouping: true
      })

      // Should create grouped notification instead of individual ones
      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          message: expect.stringContaining('2 people liked your post'),
          groupKey: 'likes-post-123'
        })
      })
    })
  })

  describe('Notification Delivery', () => {
    test('should send notification through in-app channel only', async () => {
      const notification = {
        id: 'notification-1',
        type: NotificationType.COMMENT,
        title: 'New comment',
        message: 'Someone commented',
        recipientId: 'user-123',
        recipientEmail: 'user@example.com',
        channels: JSON.stringify({ inApp: true, email: false, push: false }),
        status: NotificationStatus.PENDING
      }

      mockPrismaClient.notification.findUnique.mockResolvedValueOnce(notification)
      mockPrismaClient.notification.update.mockResolvedValueOnce({
        ...notification,
        status: NotificationStatus.DELIVERED
      })

      await notificationService.sendNotification('notification-1')

      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: 'notification-1' },
        data: { 
          status: NotificationStatus.DELIVERED,
          deliveredAt: expect.any(Date)
        }
      })

      // Email and push should not be called
      expect(mockEmailService.sendEmail).not.toHaveBeenCalled()
      expect(mockPushService.sendPush).not.toHaveBeenCalled()
    })

    test('should send notification through multiple channels', async () => {
      const notification = {
        id: 'notification-1',
        type: NotificationType.APPROVAL_REQUIRED,
        priority: NotificationPriority.HIGH,
        title: 'Urgent: Approval Required',
        message: 'Please approve the campaign immediately',
        recipientId: 'user-123',
        recipientEmail: 'user@example.com',
        channels: JSON.stringify({ inApp: true, email: true, push: true }),
        status: NotificationStatus.PENDING
      }

      mockPrismaClient.notification.findUnique.mockResolvedValueOnce(notification)
      mockEmailService.sendEmail.mockResolvedValueOnce({ success: true })
      mockPushService.sendPush.mockResolvedValueOnce({ success: true })

      await notificationService.sendNotification('notification-1')

      expect(mockEmailService.sendEmail).toHaveBeenCalledWith({
        to: 'user@example.com',
        subject: 'Urgent: Approval Required',
        body: 'Please approve the campaign immediately',
        priority: 'high'
      })

      expect(mockPushService.sendPush).toHaveBeenCalledWith({
        userId: 'user-123',
        title: 'Urgent: Approval Required',
        body: 'Please approve the campaign immediately',
        priority: 'high'
      })
    })

    test('should handle delivery failures gracefully', async () => {
      const notification = {
        id: 'notification-1',
        type: NotificationType.REMINDER,
        title: 'Reminder',
        message: 'Don\'t forget your task',
        recipientId: 'user-123',
        recipientEmail: 'user@example.com',
        channels: JSON.stringify({ inApp: true, email: true }),
        status: NotificationStatus.PENDING
      }

      mockPrismaClient.notification.findUnique.mockResolvedValueOnce(notification)
      mockEmailService.sendEmail.mockRejectedValueOnce(new Error('SMTP server unavailable'))

      await notificationService.sendNotification('notification-1')

      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: 'notification-1' },
        data: {
          status: NotificationStatus.FAILED,
          failureReason: 'Email delivery failed: SMTP server unavailable',
          failedAt: expect.any(Date)
        }
      })
    })

    test('should respect user notification preferences', async () => {
      const notification = {
        id: 'notification-1',
        type: NotificationType.COMMENT,
        title: 'New comment',
        message: 'Someone commented',
        recipientId: 'user-123',
        recipientEmail: 'user@example.com',
        channels: JSON.stringify({ inApp: true, email: true, push: true }),
        status: NotificationStatus.PENDING
      }

      const userPreferences = {
        userId: 'user-123',
        enableEmail: false, // User has disabled email
        enablePush: true,
        enableInApp: true,
        typePreferences: JSON.stringify({
          [NotificationType.COMMENT]: { email: false, push: true, inApp: true }
        })
      }

      mockPrismaClient.notification.findUnique.mockResolvedValueOnce(notification)
      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(userPreferences)

      await notificationService.sendNotification('notification-1')

      // Should not send email due to user preferences
      expect(mockEmailService.sendEmail).not.toHaveBeenCalled()
      // Should send push
      expect(mockPushService.sendPush).toHaveBeenCalled()
    })
  })

  describe('Notification Retrieval', () => {
    test('should get notifications for user with pagination', async () => {
      const mockNotifications = [
        { id: 'n1', title: 'Notification 1', read: false },
        { id: 'n2', title: 'Notification 2', read: true },
        { id: 'n3', title: 'Notification 3', read: false }
      ]

      mockPrismaClient.notification.findMany.mockResolvedValueOnce(mockNotifications)
      mockPrismaClient.notification.count.mockResolvedValueOnce(25)

      const result = await notificationService.getUserNotifications('user-123', {
        page: 1,
        limit: 10,
        includeRead: true
      })

      expect(mockPrismaClient.notification.findMany).toHaveBeenCalledWith({
        where: {
          recipientId: 'user-123',
          expiresAt: { gt: expect.any(Date) }
        },
        orderBy: { createdAt: 'desc' },
        skip: 0,
        take: 10,
        include: expect.any(Object)
      })

      expect(result).toEqual({
        notifications: mockNotifications,
        total: 25,
        page: 1,
        totalPages: 3,
        hasMore: true
      })
    })

    test('should filter notifications by type and category', async () => {
      await notificationService.getUserNotifications('user-123', {
        types: [NotificationType.COMMENT, NotificationType.MENTION],
        categories: [NotificationCategory.SOCIAL],
        unreadOnly: true
      })

      expect(mockPrismaClient.notification.findMany).toHaveBeenCalledWith({
        where: {
          recipientId: 'user-123',
          type: { in: [NotificationType.COMMENT, NotificationType.MENTION] },
          category: { in: [NotificationCategory.SOCIAL] },
          read: false,
          expiresAt: { gt: expect.any(Date) }
        },
        orderBy: { createdAt: 'desc' },
        skip: 0,
        take: 20,
        include: expect.any(Object)
      })
    })

    test('should get notification count by status', async () => {
      mockPrismaClient.notification.count
        .mockResolvedValueOnce(5) // unread
        .mockResolvedValueOnce(15) // total

      const counts = await notificationService.getNotificationCounts('user-123')

      expect(counts).toEqual({
        unread: 5,
        total: 15,
        read: 10
      })
    })

    test('should get notifications by entity', async () => {
      await notificationService.getNotificationsByEntity('campaign', 'campaign-123')

      expect(mockPrismaClient.notification.findMany).toHaveBeenCalledWith({
        where: {
          entityType: 'campaign',
          entityId: 'campaign-123'
        },
        orderBy: { createdAt: 'desc' },
        include: expect.any(Object)
      })
    })
  })

  describe('Notification State Management', () => {
    test('should mark notification as read', async () => {
      await notificationService.markAsRead('notification-1')

      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: 'notification-1' },
        data: {
          read: true,
          readAt: expect.any(Date)
        }
      })
    })

    test('should mark multiple notifications as read', async () => {
      const notificationIds = ['n1', 'n2', 'n3']

      await notificationService.markMultipleAsRead(notificationIds)

      expect(mockPrismaClient.notification.updateMany).toHaveBeenCalledWith({
        where: { id: { in: notificationIds } },
        data: {
          read: true,
          readAt: expect.any(Date)
        }
      })
    })

    test('should mark all notifications as read for user', async () => {
      await notificationService.markAllAsRead('user-123')

      expect(mockPrismaClient.notification.updateMany).toHaveBeenCalledWith({
        where: {
          recipientId: 'user-123',
          read: false
        },
        data: {
          read: true,
          readAt: expect.any(Date)
        }
      })
    })

    test('should delete notification', async () => {
      await notificationService.deleteNotification('notification-1')

      expect(mockPrismaClient.notification.delete).toHaveBeenCalledWith({
        where: { id: 'notification-1' }
      })
    })

    test('should delete expired notifications', async () => {
      const expiredCount = 50

      mockPrismaClient.notification.deleteMany.mockResolvedValueOnce({ count: expiredCount })

      const result = await notificationService.cleanupExpiredNotifications()

      expect(mockPrismaClient.notification.deleteMany).toHaveBeenCalledWith({
        where: {
          expiresAt: { lt: expect.any(Date) }
        }
      })

      expect(result.deletedCount).toBe(expiredCount)
    })

    test('should delete old read notifications', async () => {
      const deletedCount = 25
      const retentionDays = 30

      mockPrismaClient.notification.deleteMany.mockResolvedValueOnce({ count: deletedCount })

      const result = await notificationService.cleanupOldNotifications(retentionDays)

      expect(mockPrismaClient.notification.deleteMany).toHaveBeenCalledWith({
        where: {
          read: true,
          readAt: { lt: expect.any(Date) }
        }
      })

      expect(result.deletedCount).toBe(deletedCount)
    })
  })

  describe('User Preferences', () => {
    test('should get user notification preferences', async () => {
      const mockPreferences = {
        userId: 'user-123',
        enableEmail: true,
        enablePush: false,
        enableInApp: true,
        emailFrequency: EmailFrequency.IMMEDIATE,
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '08:00'
      }

      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(mockPreferences)

      const preferences = await notificationService.getUserPreferences('user-123')

      expect(preferences).toEqual(mockPreferences)
      expect(mockPrismaClient.notificationPreference.findUnique).toHaveBeenCalledWith({
        where: { userId: 'user-123' }
      })
    })

    test('should return default preferences for new user', async () => {
      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(null)

      const preferences = await notificationService.getUserPreferences('new-user')

      expect(preferences).toEqual({
        enableInApp: true,
        enableEmail: true,
        enablePush: false,
        enableDesktop: false,
        emailFrequency: EmailFrequency.IMMEDIATE,
        typePreferences: {},
        quietHoursEnabled: false,
        doNotDisturb: false,
        language: 'en',
        timezone: 'UTC'
      })
    })

    test('should update user notification preferences', async () => {
      const updatedPreferences: Partial<NotificationPreferences> = {
        enableEmail: false,
        enablePush: true,
        emailFrequency: EmailFrequency.DAILY,
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
        quietHoursTimezone: 'America/New_York'
      }

      mockPrismaClient.notificationPreference.upsert.mockResolvedValueOnce({
        userId: 'user-123',
        ...updatedPreferences
      })

      await notificationService.updateUserPreferences('user-123', updatedPreferences)

      expect(mockPrismaClient.notificationPreference.upsert).toHaveBeenCalledWith({
        where: { userId: 'user-123' },
        create: {
          userId: 'user-123',
          ...updatedPreferences
        },
        update: updatedPreferences
      })
    })

    test('should set do not disturb mode', async () => {
      const dndUntil = new Date(Date.now() + 4 * 60 * 60 * 1000) // 4 hours

      await notificationService.setDoNotDisturb('user-123', dndUntil)

      expect(mockPrismaClient.notificationPreference.upsert).toHaveBeenCalledWith({
        where: { userId: 'user-123' },
        create: {
          userId: 'user-123',
          doNotDisturb: true,
          dndUntil
        },
        update: {
          doNotDisturb: true,
          dndUntil
        }
      })
    })

    test('should check if user is in quiet hours', async () => {
      const preferences = {
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '08:00',
        quietHoursTimezone: 'UTC'
      }

      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(preferences)

      // Mock current time to be 2:00 AM UTC (within quiet hours)
      const mockDate = new Date('2024-01-01T02:00:00Z')
      vi.spyOn(global, 'Date').mockImplementation(() => mockDate as any)

      const isQuietHours = await notificationService.isUserInQuietHours('user-123')

      expect(isQuietHours).toBe(true)

      // Restore Date
      vi.restoreAllMocks()
    })
  })

  describe('Notification Templates and Formatting', () => {
    test('should format notification with template', async () => {
      const templateData = {
        userName: 'John Doe',
        campaignName: 'Summer Sale',
        approverName: 'Jane Smith'
      }

      const result = await notificationService.formatNotificationTemplate(
        'approval_request',
        templateData
      )

      expect(result).toEqual({
        title: 'Approval Required: Summer Sale',
        message: 'John Doe has submitted "Summer Sale" for your approval',
        actionText: 'Review Now'
      })
    })

    test('should handle missing template gracefully', async () => {
      const result = await notificationService.formatNotificationTemplate(
        'nonexistent_template',
        {}
      )

      expect(result).toEqual({
        title: 'Notification',
        message: 'You have a new notification',
        actionText: 'View'
      })
    })

    test('should localize notifications based on user language', async () => {
      const preferences = {
        language: 'es',
        timezone: 'Europe/Madrid'
      }

      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(preferences)

      const result = await notificationService.localizeNotification('user-123', {
        titleKey: 'approval.required',
        messageKey: 'approval.submitted',
        templateData: { campaignName: 'Campaña de Verano' }
      })

      expect(result).toEqual({
        title: 'Aprobación Requerida',
        message: 'La campaña "Campaña de Verano" necesita tu aprobación'
      })
    })
  })

  describe('Notification Analytics and Reporting', () => {
    test('should get notification delivery statistics', async () => {
      const mockStats = [
        { status: NotificationStatus.DELIVERED, _count: { status: 150 } },
        { status: NotificationStatus.FAILED, _count: { status: 10 } },
        { status: NotificationStatus.PENDING, _count: { status: 5 } }
      ]

      mockPrismaClient.notification.groupBy.mockResolvedValueOnce(mockStats)

      const stats = await notificationService.getDeliveryStatistics({
        startDate: new Date('2024-01-01'),
        endDate: new Date('2024-01-31'),
        userId: 'user-123'
      })

      expect(stats).toEqual({
        delivered: 150,
        failed: 10,
        pending: 5,
        total: 165,
        deliveryRate: 0.909 // 150/165
      })
    })

    test('should get notification engagement metrics', async () => {
      const mockEngagement = [
        { read: true, _count: { read: 120 } },
        { read: false, _count: { read: 45 } }
      ]

      mockPrismaClient.notification.groupBy.mockResolvedValueOnce(mockEngagement)

      const engagement = await notificationService.getEngagementMetrics({
        startDate: new Date('2024-01-01'),
        endDate: new Date('2024-01-31')
      })

      expect(engagement).toEqual({
        read: 120,
        unread: 45,
        total: 165,
        readRate: 0.727 // 120/165
      })
    })

    test('should get top notification types by volume', async () => {
      const mockTypeStats = [
        { type: NotificationType.COMMENT, _count: { type: 50 } },
        { type: NotificationType.MENTION, _count: { type: 30 } },
        { type: NotificationType.LIKE, _count: { type: 20 } }
      ]

      mockPrismaClient.notification.groupBy.mockResolvedValueOnce(mockTypeStats)

      const typeStats = await notificationService.getNotificationTypeStats()

      expect(typeStats).toEqual([
        { type: NotificationType.COMMENT, count: 50, percentage: 50 },
        { type: NotificationType.MENTION, count: 30, percentage: 30 },
        { type: NotificationType.LIKE, count: 20, percentage: 20 }
      ])
    })
  })

  describe('Batch Processing and Performance', () => {
    test('should process notification queue in batches', async () => {
      const pendingNotifications = Array.from({ length: 100 }, (_, i) => ({
        id: `notification-${i}`,
        status: NotificationStatus.PENDING
      }))

      mockPrismaClient.notification.findMany.mockResolvedValueOnce(pendingNotifications)

      const result = await notificationService.processPendingNotifications({
        batchSize: 25,
        maxRetries: 3
      })

      expect(result.processed).toBe(100)
      expect(result.batches).toBe(4) // 100 / 25
      expect(mockPrismaClient.notification.findMany).toHaveBeenCalledWith({
        where: { status: NotificationStatus.PENDING },
        take: 1000, // Max batch processing limit
        include: expect.any(Object)
      })
    })

    test('should handle rate limiting during batch processing', async () => {
      const notifications = Array.from({ length: 10 }, (_, i) => ({
        id: `notification-${i}`,
        status: NotificationStatus.PENDING,
        channels: JSON.stringify({ email: true })
      }))

      mockPrismaClient.notification.findMany.mockResolvedValueOnce(notifications)
      
      // Mock rate limit error
      mockEmailService.sendEmail
        .mockResolvedValueOnce({ success: true })
        .mockRejectedValueOnce(new Error('Rate limit exceeded'))
        .mockResolvedValueOnce({ success: true })

      const result = await notificationService.processPendingNotifications({
        batchSize: 10,
        respectRateLimits: true,
        rateLimitDelay: 100
      })

      expect(result.processed).toBeLessThanOrEqual(10)
      expect(result.failed).toBeGreaterThan(0)
    })

    test('should optimize database queries for large datasets', async () => {
      // Test cursor-based pagination for large notification sets
      await notificationService.getUserNotifications('user-123', {
        cursor: 'notification-cursor-123',
        limit: 50
      })

      expect(mockPrismaClient.notification.findMany).toHaveBeenCalledWith({
        where: expect.objectContaining({
          recipientId: 'user-123'
        }),
        cursor: { id: 'notification-cursor-123' },
        skip: 1, // Skip the cursor
        take: 50,
        orderBy: { createdAt: 'desc' },
        include: expect.any(Object)
      })
    })
  })

  describe('Error Handling and Edge Cases', () => {
    test('should handle database connection errors', async () => {
      mockPrismaClient.notification.create.mockRejectedValueOnce(
        new Error('Database connection lost')
      )

      const notificationData: NotificationData = {
        type: NotificationType.SYSTEM_ALERT,
        category: NotificationCategory.SYSTEM,
        title: 'Test',
        message: 'Test message',
        recipientId: 'user-123'
      }

      await expect(notificationService.createNotification(notificationData))
        .rejects.toThrow('Database connection lost')
    })

    test('should handle invalid notification data', async () => {
      const invalidData = {
        // Missing required fields
        title: 'Test'
      } as NotificationData

      await expect(notificationService.createNotification(invalidData))
        .rejects.toThrow()
    })

    test('should handle circular references in metadata', async () => {
      const metadataWithCircular: any = { name: 'test' }
      metadataWithCircular.self = metadataWithCircular

      const notificationData: NotificationData = {
        type: NotificationType.GENERAL,
        category: NotificationCategory.GENERAL,
        title: 'Test',
        message: 'Test message',
        recipientId: 'user-123',
        metadata: metadataWithCircular
      }

      await notificationService.createNotification(notificationData)

      // Should handle serialization error gracefully
      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          metadata: '[Circular reference detected]'
        })
      })
    })

    test('should handle timezone conversion errors', async () => {
      const preferences = {
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '08:00',
        quietHoursTimezone: 'Invalid/Timezone'
      }

      mockPrismaClient.notificationPreference.findUnique.mockResolvedValueOnce(preferences)

      const isQuietHours = await notificationService.isUserInQuietHours('user-123')

      // Should default to UTC when timezone is invalid
      expect(isQuietHours).toBeDefined()
    })

    test('should handle service unavailability gracefully', async () => {
      // Email service unavailable
      const notificationService = new NotificationService(
        mockPrismaClient,
        null, // No email service
        mockPushService
      )

      const notification = {
        id: 'notification-1',
        channels: JSON.stringify({ email: true, push: true }),
        status: NotificationStatus.PENDING
      }

      mockPrismaClient.notification.findUnique.mockResolvedValueOnce(notification)

      await notificationService.sendNotification('notification-1')

      // Should still send push notification
      expect(mockPushService.sendPush).toHaveBeenCalled()
      
      // Should log email failure
      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: 'notification-1' },
        data: expect.objectContaining({
          status: NotificationStatus.FAILED,
          failureReason: expect.stringContaining('Email service unavailable')
        })
      })
    })
  })
})

describe('NotificationService Integration Tests', () => {
  let notificationService: NotificationService

  beforeEach(() => {
    vi.clearAllMocks()
    notificationService = new NotificationService(
      mockPrismaClient,
      mockEmailService,
      mockPushService
    )
  })

  describe('End-to-End Notification Flow', () => {
    test('should complete full notification lifecycle', async () => {
      // 1. Create notification
      const notificationData: NotificationData = {
        type: NotificationType.APPROVAL_REQUEST,
        category: NotificationCategory.WORKFLOW,
        priority: NotificationPriority.HIGH,
        title: 'Urgent: Campaign Approval Required',
        message: 'Please review and approve the new campaign',
        actionText: 'Review Campaign',
        actionUrl: '/campaigns/123/approve',
        recipientId: 'manager-456',
        recipientEmail: 'manager@company.com',
        senderId: 'creator-123',
        senderName: 'John Creator',
        entityType: 'campaign',
        entityId: 'campaign-789',
        channels: {
          inApp: true,
          email: true,
          push: true
        }
      }

      const createdNotification = {
        id: 'notification-urgent-123',
        ...notificationData,
        status: NotificationStatus.PENDING,
        createdAt: new Date()
      }

      mockPrismaClient.notification.create.mockResolvedValueOnce(createdNotification)

      // Create the notification
      const notification = await notificationService.createNotification(notificationData)
      expect(notification.id).toBe('notification-urgent-123')

      // 2. Send notification
      mockPrismaClient.notification.findUnique.mockResolvedValueOnce({
        ...createdNotification,
        channels: JSON.stringify(notificationData.channels)
      })
      mockEmailService.sendEmail.mockResolvedValueOnce({ success: true, messageId: 'email-123' })
      mockPushService.sendPush.mockResolvedValueOnce({ success: true, pushId: 'push-456' })

      await notificationService.sendNotification(notification.id)

      // Verify email was sent
      expect(mockEmailService.sendEmail).toHaveBeenCalledWith({
        to: 'manager@company.com',
        subject: 'Urgent: Campaign Approval Required',
        body: 'Please review and approve the new campaign',
        priority: 'high',
        actionText: 'Review Campaign',
        actionUrl: '/campaigns/123/approve'
      })

      // Verify push was sent
      expect(mockPushService.sendPush).toHaveBeenCalledWith({
        userId: 'manager-456',
        title: 'Urgent: Campaign Approval Required',
        body: 'Please review and approve the new campaign',
        priority: 'high',
        actionUrl: '/campaigns/123/approve'
      })

      // 3. User reads notification
      await notificationService.markAsRead(notification.id)

      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: notification.id },
        data: {
          read: true,
          readAt: expect.any(Date)
        }
      })
    })

    test('should handle workflow-based notification chain', async () => {
      // Simulate approval workflow notifications
      const workflowSteps = [
        {
          type: NotificationType.APPROVAL_REQUEST,
          title: 'Content Review Required',
          recipientId: 'reviewer-1'
        },
        {
          type: NotificationType.APPROVAL_APPROVED,
          title: 'Content Approved - Next Stage',
          recipientId: 'approver-2'
        },
        {
          type: NotificationType.WORKFLOW_COMPLETE,
          title: 'Campaign Ready for Publishing',
          recipientId: 'publisher-3'
        }
      ]

      for (const [index, step] of workflowSteps.entries()) {
        const notification: NotificationData = {
          ...step,
          category: NotificationCategory.WORKFLOW,
          message: `Step ${index + 1} of workflow`,
          entityType: 'campaign',
          entityId: 'campaign-workflow-123'
        }

        await notificationService.createNotification(notification)
      }

      expect(mockPrismaClient.notification.create).toHaveBeenCalledTimes(3)
      
      // Verify each step was created with correct workflow context
      workflowSteps.forEach((step, index) => {
        expect(mockPrismaClient.notification.create).toHaveBeenNthCalledWith(index + 1, {
          data: expect.objectContaining({
            type: step.type,
            recipientId: step.recipientId,
            entityType: 'campaign',
            entityId: 'campaign-workflow-123'
          })
        })
      })
    })
  })

  describe('Real-time Notification Scenarios', () => {
    test('should handle real-time collaboration notifications', async () => {
      // Simulate multiple users collaborating on a document
      const collaborationEvents = [
        {
          type: NotificationType.COMMENT,
          senderId: 'user-a',
          message: 'User A commented on the document'
        },
        {
          type: NotificationType.MENTION,
          senderId: 'user-b', 
          message: '@user-c check out this section'
        },
        {
          type: NotificationType.EDIT,
          senderId: 'user-c',
          message: 'User C made edits to the document'
        }
      ]

      const notifications = collaborationEvents.map(event => ({
        ...event,
        category: NotificationCategory.COLLABORATION,
        title: 'Document Activity',
        recipientId: 'document-owner',
        entityType: 'document',
        entityId: 'doc-collab-456',
        channels: { inApp: true, push: false, email: false }
      }))

      await notificationService.createBulkNotifications(notifications, {
        enableGrouping: true,
        groupingWindow: 300 // 5 minutes
      })

      // Should group notifications for same document within time window
      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          title: 'Document Activity',
          message: expect.stringContaining('3 activities'),
          groupKey: expect.stringContaining('doc-collab-456')
        })
      })
    })

    test('should handle notification storm prevention', async () => {
      // Simulate many rapid notifications that should be throttled
      const rapidNotifications = Array.from({ length: 50 }, (_, i) => ({
        type: NotificationType.LIKE,
        category: NotificationCategory.SOCIAL,
        title: 'New like',
        message: `User ${i} liked your post`,
        recipientId: 'content-creator',
        entityType: 'post',
        entityId: 'viral-post-123',
        groupKey: 'likes-viral-post-123'
      }))

      await notificationService.createBulkNotifications(rapidNotifications, {
        enableThrottling: true,
        throttleLimit: 5, // Max 5 notifications per minute
        enableGrouping: true
      })

      // Should create grouped notification instead of 50 individual ones
      expect(mockPrismaClient.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          message: expect.stringContaining('50 people liked'),
          groupKey: 'likes-viral-post-123'
        })
      })
    })
  })

  describe('Performance and Scale Testing', () => {
    test('should handle large user base notification distribution', async () => {
      // Simulate system-wide announcement to all users
      const userIds = Array.from({ length: 10000 }, (_, i) => `user-${i}`)
      
      const systemNotification: NotificationData = {
        type: NotificationType.SYSTEM_ANNOUNCEMENT,
        category: NotificationCategory.SYSTEM,
        priority: NotificationPriority.LOW,
        title: 'Scheduled Maintenance Notice',
        message: 'System will be under maintenance tomorrow at 2 AM UTC',
        recipientId: '', // Will be set per user
        channels: { inApp: true, email: false } // Reduce load
      }

      const notifications = userIds.map(userId => ({
        ...systemNotification,
        recipientId: userId
      }))

      const startTime = Date.now()
      await notificationService.createBulkNotifications(notifications, {
        batchSize: 1000,
        continueOnError: true
      })
      const endTime = Date.now()

      // Should process efficiently (under 5 seconds)
      expect(endTime - startTime).toBeLessThan(5000)
      
      // Should have batched the creation
      const createCalls = mockPrismaClient.notification.create.mock.calls.length
      expect(createCalls).toBeLessThanOrEqual(10) // Batching should reduce calls
    })
  })
})