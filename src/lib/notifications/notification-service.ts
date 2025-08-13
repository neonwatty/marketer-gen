import { PrismaClient, NotificationType, NotificationCategory, NotificationPriority, NotificationStatus, NotificationChannel, EmailFrequency } from '@prisma/client'
import { nanoid } from 'nanoid'

export interface NotificationData {
  type: NotificationType
  category: NotificationCategory
  priority?: NotificationPriority
  title: string
  message: string
  actionText?: string
  actionUrl?: string
  recipientId: string
  recipientEmail?: string
  senderId?: string
  senderName?: string
  entityType?: string
  entityId?: string
  metadata?: Record<string, any>
  channels?: {
    inApp?: boolean
    email?: boolean
    push?: boolean
    desktop?: boolean
  }
  groupKey?: string
  expiresAt?: Date
}

export interface NotificationPreferences {
  enableInApp: boolean
  enableEmail: boolean
  enablePush: boolean
  enableDesktop: boolean
  emailFrequency: EmailFrequency
  digestTime?: string
  typePreferences: Record<string, {
    inApp: boolean
    email: boolean
    push: boolean
    desktop: boolean
  }>
  quietHoursEnabled: boolean
  quietHoursStart?: string
  quietHoursEnd?: string
  quietHoursTimezone?: string
  doNotDisturb: boolean
  dndUntil?: Date
  language: string
  timezone: string
}

export interface BatchingConfig {
  enabled: boolean
  windowMinutes: number
  maxItems: number
  types: NotificationType[]
}

export interface DeliveryResult {
  success: boolean
  channel: NotificationChannel
  deliveredAt?: Date
  error?: string
  externalId?: string
  provider?: string
}

export class NotificationService {
  private prisma: PrismaClient
  private batchingConfigs: Map<string, BatchingConfig> = new Map()

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
    this.initializeBatchingConfigs()
  }

  /**
   * Create and send a notification
   */
  async createNotification(data: NotificationData): Promise<string> {
    // Get user preferences
    const preferences = await this.getUserPreferences(data.recipientId)
    
    // Check if user wants this type of notification
    if (!this.shouldSendNotification(data, preferences)) {
      console.log(`Notification blocked by user preferences: ${data.type} for user ${data.recipientId}`)
      return ''
    }

    // Check if we should batch this notification
    if (this.shouldBatchNotification(data, preferences)) {
      return await this.addToBatch(data)
    }

    // Create the notification
    const notification = await this.prisma.notification.create({
      data: {
        type: data.type,
        category: data.category,
        priority: data.priority || NotificationPriority.MEDIUM,
        title: data.title,
        message: data.message,
        actionText: data.actionText,
        actionUrl: data.actionUrl,
        recipientId: data.recipientId,
        recipientEmail: data.recipientEmail,
        senderId: data.senderId,
        senderName: data.senderName,
        entityType: data.entityType,
        entityId: data.entityId,
        metadata: data.metadata ? JSON.stringify(data.metadata) : null,
        groupKey: data.groupKey,
        expiresAt: data.expiresAt,
        
        // Channel preferences (merged with user preferences)
        inApp: data.channels?.inApp ?? preferences.enableInApp,
        email: data.channels?.email ?? (preferences.enableEmail && preferences.emailFrequency === EmailFrequency.IMMEDIATE),
        push: data.channels?.push ?? preferences.enablePush,
        desktop: data.channels?.desktop ?? preferences.enableDesktop
      }
    })

    // Deliver the notification
    await this.deliverNotification(notification.id)
    
    return notification.id
  }

  /**
   * Deliver a notification through configured channels
   */
  async deliverNotification(notificationId: string): Promise<DeliveryResult[]> {
    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId }
    })

    if (!notification) {
      throw new Error(`Notification ${notificationId} not found`)
    }

    const results: DeliveryResult[] = []

    // In-app notification (always delivered immediately)
    if (notification.inApp) {
      const result = await this.deliverInApp(notification)
      results.push(result)
    }

    // Email notification
    if (notification.email && notification.recipientEmail) {
      const result = await this.deliverEmail(notification)
      results.push(result)
    }

    // Push notification
    if (notification.push) {
      const result = await this.deliverPush(notification)
      results.push(result)
    }

    // Desktop notification
    if (notification.desktop) {
      const result = await this.deliverDesktop(notification)
      results.push(result)
    }

    // Update notification status
    const hasSuccessfulDelivery = results.some(r => r.success)
    if (hasSuccessfulDelivery) {
      await this.prisma.notification.update({
        where: { id: notificationId },
        data: {
          status: NotificationStatus.DELIVERED,
          deliveredAt: new Date()
        }
      })
    }

    return results
  }

  /**
   * In-app notification delivery (just mark as ready)
   */
  private async deliverInApp(notification: any): Promise<DeliveryResult> {
    try {
      // In-app notifications are just stored in the database
      // Real-time delivery happens through WebSocket (separate system)
      
      await this.logDelivery(notification.id, NotificationChannel.IN_APP, 'DELIVERED')
      
      return {
        success: true,
        channel: NotificationChannel.IN_APP,
        deliveredAt: new Date()
      }
    } catch (error) {
      await this.logDelivery(notification.id, NotificationChannel.IN_APP, 'FAILED', error instanceof Error ? error.message : 'Unknown error')
      return {
        success: false,
        channel: NotificationChannel.IN_APP,
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  /**
   * Email notification delivery (placeholder)
   */
  private async deliverEmail(notification: any): Promise<DeliveryResult> {
    try {
      // In a real implementation, this would integrate with an email service
      // like SendGrid, Mailgun, SES, etc.
      
      console.log(`Email notification would be sent to ${notification.recipientEmail}:`)
      console.log(`Subject: ${notification.title}`)
      console.log(`Body: ${notification.message}`)
      
      // Simulate delivery delay
      await new Promise(resolve => setTimeout(resolve, 100))
      
      const externalId = `email_${nanoid()}`
      await this.logDelivery(notification.id, NotificationChannel.EMAIL, 'SENT', undefined, externalId, 'placeholder-email-service')
      
      return {
        success: true,
        channel: NotificationChannel.EMAIL,
        deliveredAt: new Date(),
        externalId,
        provider: 'placeholder-email-service'
      }
    } catch (error) {
      await this.logDelivery(notification.id, NotificationChannel.EMAIL, 'FAILED', error instanceof Error ? error.message : 'Unknown error')
      return {
        success: false,
        channel: NotificationChannel.EMAIL,
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  /**
   * Push notification delivery (placeholder)
   */
  private async deliverPush(notification: any): Promise<DeliveryResult> {
    try {
      // In a real implementation, this would integrate with push services
      // like FCM, APNs, Web Push, etc.
      
      console.log(`Push notification would be sent to user ${notification.recipientId}:`)
      console.log(`Title: ${notification.title}`)
      console.log(`Body: ${notification.message}`)
      
      const externalId = `push_${nanoid()}`
      await this.logDelivery(notification.id, NotificationChannel.PUSH, 'SENT', undefined, externalId, 'placeholder-push-service')
      
      return {
        success: true,
        channel: NotificationChannel.PUSH,
        deliveredAt: new Date(),
        externalId,
        provider: 'placeholder-push-service'
      }
    } catch (error) {
      await this.logDelivery(notification.id, NotificationChannel.PUSH, 'FAILED', error instanceof Error ? error.message : 'Unknown error')
      return {
        success: false,
        channel: NotificationChannel.PUSH,
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  /**
   * Desktop notification delivery (placeholder)
   */
  private async deliverDesktop(notification: any): Promise<DeliveryResult> {
    try {
      // Desktop notifications would be handled client-side
      // This just logs the intent to deliver
      
      await this.logDelivery(notification.id, NotificationChannel.DESKTOP, 'DELIVERED')
      
      return {
        success: true,
        channel: NotificationChannel.DESKTOP,
        deliveredAt: new Date()
      }
    } catch (error) {
      await this.logDelivery(notification.id, NotificationChannel.DESKTOP, 'FAILED', error instanceof Error ? error.message : 'Unknown error')
      return {
        success: false,
        channel: NotificationChannel.DESKTOP,
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  /**
   * Log delivery attempt
   */
  private async logDelivery(
    notificationId: string,
    channel: NotificationChannel,
    status: string,
    errorMessage?: string,
    externalId?: string,
    provider?: string
  ): Promise<void> {
    await this.prisma.notificationDelivery.create({
      data: {
        notificationId,
        channel,
        status: status as any,
        errorMessage,
        externalId,
        provider,
        deliveredAt: status === 'DELIVERED' || status === 'SENT' ? new Date() : undefined,
        failedAt: status === 'FAILED' ? new Date() : undefined
      }
    })
  }

  /**
   * Get user notification preferences
   */
  async getUserPreferences(userId: string): Promise<NotificationPreferences> {
    let preferences = await this.prisma.notificationPreference.findUnique({
      where: { userId }
    })

    // Create default preferences if none exist
    if (!preferences) {
      preferences = await this.prisma.notificationPreference.create({
        data: {
          userId,
          enableInApp: true,
          enableEmail: true,
          enablePush: false,
          enableDesktop: false,
          emailFrequency: EmailFrequency.IMMEDIATE,
          typePreferences: JSON.stringify({}),
          quietHoursEnabled: false,
          doNotDisturb: false,
          language: 'en',
          timezone: 'UTC'
        }
      })
    }

    return {
      enableInApp: preferences.enableInApp,
      enableEmail: preferences.enableEmail,
      enablePush: preferences.enablePush,
      enableDesktop: preferences.enableDesktop,
      emailFrequency: preferences.emailFrequency,
      digestTime: preferences.digestTime || undefined,
      typePreferences: preferences.typePreferences ? JSON.parse(preferences.typePreferences) : {},
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart || undefined,
      quietHoursEnd: preferences.quietHoursEnd || undefined,
      quietHoursTimezone: preferences.quietHoursTimezone || undefined,
      doNotDisturb: preferences.doNotDisturb,
      dndUntil: preferences.dndUntil || undefined,
      language: preferences.language,
      timezone: preferences.timezone
    }
  }

  /**
   * Update user notification preferences
   */
  async updateUserPreferences(userId: string, updates: Partial<NotificationPreferences>): Promise<void> {
    await this.prisma.notificationPreference.upsert({
      where: { userId },
      create: {
        userId,
        enableInApp: updates.enableInApp ?? true,
        enableEmail: updates.enableEmail ?? true,
        enablePush: updates.enablePush ?? false,
        enableDesktop: updates.enableDesktop ?? false,
        emailFrequency: updates.emailFrequency ?? EmailFrequency.IMMEDIATE,
        digestTime: updates.digestTime,
        typePreferences: JSON.stringify(updates.typePreferences || {}),
        quietHoursEnabled: updates.quietHoursEnabled ?? false,
        quietHoursStart: updates.quietHoursStart,
        quietHoursEnd: updates.quietHoursEnd,
        quietHoursTimezone: updates.quietHoursTimezone,
        doNotDisturb: updates.doNotDisturb ?? false,
        dndUntil: updates.dndUntil,
        language: updates.language ?? 'en',
        timezone: updates.timezone ?? 'UTC'
      },
      update: {
        enableInApp: updates.enableInApp,
        enableEmail: updates.enableEmail,
        enablePush: updates.enablePush,
        enableDesktop: updates.enableDesktop,
        emailFrequency: updates.emailFrequency,
        digestTime: updates.digestTime,
        typePreferences: updates.typePreferences ? JSON.stringify(updates.typePreferences) : undefined,
        quietHoursEnabled: updates.quietHoursEnabled,
        quietHoursStart: updates.quietHoursStart,
        quietHoursEnd: updates.quietHoursEnd,
        quietHoursTimezone: updates.quietHoursTimezone,
        doNotDisturb: updates.doNotDisturb,
        dndUntil: updates.dndUntil,
        language: updates.language,
        timezone: updates.timezone
      }
    })
  }

  /**
   * Get notifications for a user
   */
  async getUserNotifications(
    userId: string,
    options: {
      limit?: number
      offset?: number
      status?: NotificationStatus
      category?: NotificationCategory
      unreadOnly?: boolean
    } = {}
  ) {
    const {
      limit = 50,
      offset = 0,
      status,
      category,
      unreadOnly = false
    } = options

    const where: any = { recipientId: userId }
    
    if (status) where.status = status
    if (category) where.category = category
    if (unreadOnly) where.readAt = null

    const [notifications, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: offset,
        take: limit,
        select: {
          id: true,
          type: true,
          category: true,
          priority: true,
          title: true,
          message: true,
          actionText: true,
          actionUrl: true,
          senderId: true,
          senderName: true,
          status: true,
          readAt: true,
          createdAt: true,
          entityType: true,
          entityId: true,
          metadata: true,
          expiresAt: true
        }
      }),
      this.prisma.notification.count({ where })
    ])

    return {
      notifications: notifications.map(n => ({
        ...n,
        metadata: n.metadata ? JSON.parse(n.metadata) : null
      })),
      total,
      hasMore: offset + limit < total
    }
  }

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId: string, userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        recipientId: userId,
        readAt: null
      },
      data: {
        status: NotificationStatus.READ,
        readAt: new Date()
      }
    })
  }

  /**
   * Mark all notifications as read for a user
   */
  async markAllAsRead(userId: string): Promise<number> {
    const result = await this.prisma.notification.updateMany({
      where: {
        recipientId: userId,
        readAt: null
      },
      data: {
        status: NotificationStatus.READ,
        readAt: new Date()
      }
    })

    return result.count
  }

  /**
   * Get unread count for a user
   */
  async getUnreadCount(userId: string): Promise<number> {
    return await this.prisma.notification.count({
      where: {
        recipientId: userId,
        readAt: null,
        inApp: true
      }
    })
  }

  /**
   * Check if notification should be sent based on user preferences
   */
  private shouldSendNotification(data: NotificationData, preferences: NotificationPreferences): boolean {
    // Check do not disturb
    if (preferences.doNotDisturb) {
      if (!preferences.dndUntil || preferences.dndUntil > new Date()) {
        // Only allow urgent notifications during DND
        return data.priority === NotificationPriority.URGENT
      }
    }

    // Check quiet hours for non-urgent notifications
    if (preferences.quietHoursEnabled && data.priority !== NotificationPriority.URGENT) {
      if (this.isInQuietHours(preferences)) {
        return false
      }
    }

    // Check type-specific preferences
    const typePrefs = preferences.typePreferences[data.type]
    if (typePrefs) {
      // If user has specific preferences for this type, use them
      return typePrefs.inApp || typePrefs.email || typePrefs.push || typePrefs.desktop
    }

    // Default to global preferences
    return preferences.enableInApp || preferences.enableEmail || preferences.enablePush || preferences.enableDesktop
  }

  /**
   * Check if current time is in user's quiet hours
   */
  private isInQuietHours(preferences: NotificationPreferences): boolean {
    if (!preferences.quietHoursEnabled || !preferences.quietHoursStart || !preferences.quietHoursEnd) {
      return false
    }

    // For simplicity, assuming UTC timezone
    // In production, you'd use the user's timezone
    const now = new Date()
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`
    
    const start = preferences.quietHoursStart
    const end = preferences.quietHoursEnd
    
    if (start <= end) {
      return currentTime >= start && currentTime <= end
    } else {
      // Overnight quiet hours
      return currentTime >= start || currentTime <= end
    }
  }

  /**
   * Check if notification should be batched
   */
  private shouldBatchNotification(data: NotificationData, preferences: NotificationPreferences): boolean {
    const config = this.batchingConfigs.get(data.type)
    if (!config || !config.enabled) return false

    // Don't batch urgent notifications
    if (data.priority === NotificationPriority.URGENT) return false

    // Check if user wants immediate emails
    if (preferences.emailFrequency === EmailFrequency.IMMEDIATE) return false

    return config.types.includes(data.type)
  }

  /**
   * Add notification to batch
   */
  private async addToBatch(data: NotificationData): Promise<string> {
    const config = this.batchingConfigs.get(data.type)!
    const windowStart = new Date()
    const windowEnd = new Date(windowStart.getTime() + config.windowMinutes * 60 * 1000)
    
    const batchKey = `${data.recipientId}_${data.type}_${data.category}`
    
    // Find or create batch
    let batch = await this.prisma.notificationBatch.findUnique({
      where: { batchKey }
    })

    if (!batch || batch.windowEnd < new Date()) {
      // Create new batch
      batch = await this.prisma.notificationBatch.create({
        data: {
          batchKey,
          recipientId: data.recipientId,
          type: data.type,
          category: data.category,
          scheduledAt: windowEnd,
          windowStart,
          windowEnd,
          maxItems: config.maxItems,
          summary: data.title,
          count: 1
        }
      })
    } else {
      // Update existing batch
      await this.prisma.notificationBatch.update({
        where: { id: batch.id },
        data: {
          count: { increment: 1 },
          summary: `${batch.summary} and ${data.title}`
        }
      })
    }

    // Create the notification but don't deliver it yet
    const notification = await this.prisma.notification.create({
      data: {
        type: data.type,
        category: data.category,
        priority: data.priority || NotificationPriority.MEDIUM,
        title: data.title,
        message: data.message,
        actionText: data.actionText,
        actionUrl: data.actionUrl,
        recipientId: data.recipientId,
        recipientEmail: data.recipientEmail,
        senderId: data.senderId,
        senderName: data.senderName,
        entityType: data.entityType,
        entityId: data.entityId,
        metadata: data.metadata ? JSON.stringify(data.metadata) : null,
        groupKey: data.groupKey,
        batchId: batch.id,
        expiresAt: data.expiresAt,
        
        // Only in-app for batched notifications
        inApp: true,
        email: false,
        push: false,
        desktop: false
      }
    })

    return notification.id
  }

  /**
   * Process pending batches
   */
  async processPendingBatches(): Promise<void> {
    const now = new Date()
    
    const pendingBatches = await this.prisma.notificationBatch.findMany({
      where: {
        status: 'PENDING',
        scheduledAt: { lte: now }
      }
    })

    for (const batch of pendingBatches) {
      try {
        await this.processBatch(batch.id)
      } catch (error) {
        console.error(`Failed to process batch ${batch.id}:`, error)
        await this.prisma.notificationBatch.update({
          where: { id: batch.id },
          data: { status: 'FAILED' }
        })
      }
    }
  }

  /**
   * Process a single batch
   */
  private async processBatch(batchId: string): Promise<void> {
    const batch = await this.prisma.notificationBatch.findUnique({
      where: { id: batchId }
    })

    if (!batch) return

    // Mark batch as processing
    await this.prisma.notificationBatch.update({
      where: { id: batchId },
      data: { status: 'PROCESSING' }
    })

    // Get user preferences
    const preferences = await this.getUserPreferences(batch.recipientId)

    // Create summary notification
    await this.createNotification({
      type: batch.type,
      category: batch.category,
      title: `${batch.count} ${batch.type.toLowerCase()} notifications`,
      message: batch.summary,
      recipientId: batch.recipientId,
      channels: {
        inApp: true,
        email: preferences.enableEmail,
        push: false,
        desktop: false
      },
      metadata: {
        batchId: batch.id,
        originalCount: batch.count
      }
    })

    // Mark batch as sent
    await this.prisma.notificationBatch.update({
      where: { id: batchId },
      data: {
        status: 'SENT',
        sentAt: new Date()
      }
    })
  }

  /**
   * Initialize default batching configurations
   */
  private initializeBatchingConfigs(): void {
    // Comments can be batched
    this.batchingConfigs.set(NotificationType.COMMENT, {
      enabled: true,
      windowMinutes: 15,
      maxItems: 5,
      types: [NotificationType.COMMENT]
    })

    // Content updates can be batched
    this.batchingConfigs.set(NotificationType.CONTENT_UPDATE, {
      enabled: true,
      windowMinutes: 30,
      maxItems: 10,
      types: [NotificationType.CONTENT_UPDATE, NotificationType.CAMPAIGN_UPDATE]
    })

    // Mentions should be batched more aggressively
    this.batchingConfigs.set(NotificationType.MENTION, {
      enabled: true,
      windowMinutes: 5,
      maxItems: 3,
      types: [NotificationType.MENTION]
    })
  }

  /**
   * Clean up old notifications
   */
  async cleanupOldNotifications(olderThanDays = 90): Promise<number> {
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays)

    const result = await this.prisma.notification.deleteMany({
      where: {
        createdAt: { lt: cutoffDate },
        isArchived: false
      }
    })

    return result.count
  }
}

// Singleton instance
let notificationService: NotificationService | null = null

export function getNotificationService(prisma: PrismaClient): NotificationService {
  if (!notificationService) {
    notificationService = new NotificationService(prisma)
  }
  return notificationService
}

export default NotificationService