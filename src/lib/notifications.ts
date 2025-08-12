import { ContentStatus, ApprovalStatus } from '@prisma/client'
import { ApprovalAction } from './approval-workflow'

export interface NotificationData {
  id: string
  type: NotificationEventType
  title: string
  message: string
  contentId: string
  contentTitle: string
  fromUserId?: string
  fromUserName?: string
  toUserId?: string
  toUserRole?: string
  action: ApprovalAction
  fromStatus: ContentStatus
  toStatus: ContentStatus
  comment?: string
  createdAt: Date
  isRead: boolean
  priority: 'low' | 'medium' | 'high'
  metadata?: Record<string, any>
}

export type NotificationEventType = 
  | 'content_submitted'
  | 'content_approved'
  | 'content_rejected'
  | 'content_revision_requested'
  | 'content_published'
  | 'content_archived'
  | 'bulk_action_completed'
  | 'workflow_comment_added'

// Notification templates
export const NOTIFICATION_TEMPLATES: Record<NotificationEventType, {
  title: (data: any) => string
  message: (data: any) => string
  priority: 'low' | 'medium' | 'high'
}> = {
  content_submitted: {
    title: (data) => 'Content Submitted for Review',
    message: (data) => `"${data.contentTitle}" has been submitted for review by ${data.fromUserName || 'a user'}.`,
    priority: 'medium'
  },
  content_approved: {
    title: (data) => 'Content Approved',
    message: (data) => `"${data.contentTitle}" has been approved by ${data.fromUserName || 'an approver'}.`,
    priority: 'high'
  },
  content_rejected: {
    title: (data) => 'Content Rejected',
    message: (data) => `"${data.contentTitle}" has been rejected by ${data.fromUserName || 'an approver'}.${data.comment ? ` Reason: ${data.comment}` : ''}`,
    priority: 'high'
  },
  content_revision_requested: {
    title: (data) => 'Revision Requested',
    message: (data) => `Revisions have been requested for "${data.contentTitle}" by ${data.fromUserName || 'a reviewer'}.${data.comment ? ` Feedback: ${data.comment}` : ''}`,
    priority: 'high'
  },
  content_published: {
    title: (data) => 'Content Published',
    message: (data) => `"${data.contentTitle}" has been published by ${data.fromUserName || 'a publisher'}.`,
    priority: 'medium'
  },
  content_archived: {
    title: (data) => 'Content Archived',
    message: (data) => `"${data.contentTitle}" has been archived by ${data.fromUserName || 'an admin'}.`,
    priority: 'low'
  },
  bulk_action_completed: {
    title: (data) => 'Bulk Action Completed',
    message: (data) => `Bulk ${data.action} completed for ${data.itemCount} items by ${data.fromUserName || 'a user'}.`,
    priority: 'medium'
  },
  workflow_comment_added: {
    title: (data) => 'New Comment Added',
    message: (data) => `${data.fromUserName || 'A user'} added a comment to "${data.contentTitle}": "${data.comment.substring(0, 100)}${data.comment.length > 100 ? '...' : ''}"`,
    priority: 'low'
  }
}

// Notification service
export class NotificationService {
  private notifications: Map<string, NotificationData[]> = new Map()

  // Create a notification
  createNotification(data: Partial<NotificationData> & {
    type: NotificationEventType
    contentId: string
    contentTitle: string
    action: ApprovalAction
    fromStatus: ContentStatus
    toStatus: ContentStatus
  }): NotificationData {
    const template = NOTIFICATION_TEMPLATES[data.type]
    
    const notification: NotificationData = {
      id: `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: data.type,
      title: template.title(data),
      message: template.message(data),
      contentId: data.contentId,
      contentTitle: data.contentTitle,
      fromUserId: data.fromUserId,
      fromUserName: data.fromUserName,
      toUserId: data.toUserId,
      toUserRole: data.toUserRole,
      action: data.action,
      fromStatus: data.fromStatus,
      toStatus: data.toStatus,
      comment: data.comment,
      createdAt: new Date(),
      isRead: false,
      priority: template.priority,
      metadata: data.metadata
    }

    return notification
  }

  // Add notification for a user
  addNotification(userId: string, notification: NotificationData): void {
    if (!this.notifications.has(userId)) {
      this.notifications.set(userId, [])
    }
    
    const userNotifications = this.notifications.get(userId)!
    userNotifications.unshift(notification) // Add to beginning
    
    // Keep only last 100 notifications per user
    if (userNotifications.length > 100) {
      userNotifications.splice(100)
    }
  }

  // Get notifications for a user
  getNotifications(userId: string, limit = 50, offset = 0): NotificationData[] {
    const userNotifications = this.notifications.get(userId) || []
    return userNotifications.slice(offset, offset + limit)
  }

  // Get unread count for user
  getUnreadCount(userId: string): number {
    const userNotifications = this.notifications.get(userId) || []
    return userNotifications.filter(n => !n.isRead).length
  }

  // Mark notification as read
  markAsRead(userId: string, notificationId: string): boolean {
    const userNotifications = this.notifications.get(userId) || []
    const notification = userNotifications.find(n => n.id === notificationId)
    
    if (notification) {
      notification.isRead = true
      return true
    }
    
    return false
  }

  // Mark all notifications as read
  markAllAsRead(userId: string): void {
    const userNotifications = this.notifications.get(userId) || []
    userNotifications.forEach(n => n.isRead = true)
  }

  // Delete notification
  deleteNotification(userId: string, notificationId: string): boolean {
    const userNotifications = this.notifications.get(userId) || []
    const index = userNotifications.findIndex(n => n.id === notificationId)
    
    if (index !== -1) {
      userNotifications.splice(index, 1)
      return true
    }
    
    return false
  }

  // Clear all notifications for user
  clearNotifications(userId: string): void {
    this.notifications.delete(userId)
  }

  // Notify workflow action - determines who should be notified
  async notifyWorkflowAction({
    contentId,
    contentTitle,
    action,
    fromStatus,
    toStatus,
    fromUserId,
    fromUserName,
    comment,
    metadata
  }: {
    contentId: string
    contentTitle: string
    action: ApprovalAction
    fromStatus: ContentStatus
    toStatus: ContentStatus
    fromUserId?: string
    fromUserName?: string
    comment?: string
    metadata?: Record<string, any>
  }): Promise<void> {
    const notificationsToSend: Array<{
      userId: string
      userRole?: string
      type: NotificationEventType
    }> = []

    // Determine notification recipients based on action
    switch (action) {
      case 'submit_for_review':
        // Notify approvers and reviewers
        notificationsToSend.push(
          { userId: 'approvers', userRole: 'approver', type: 'content_submitted' },
          { userId: 'reviewers', userRole: 'reviewer', type: 'content_submitted' }
        )
        break

      case 'approve':
        // Notify content creator and publishers
        if (metadata?.originalCreatorId) {
          notificationsToSend.push({
            userId: metadata.originalCreatorId,
            type: 'content_approved'
          })
        }
        notificationsToSend.push(
          { userId: 'publishers', userRole: 'publisher', type: 'content_approved' }
        )
        break

      case 'reject':
        // Notify content creator
        if (metadata?.originalCreatorId) {
          notificationsToSend.push({
            userId: metadata.originalCreatorId,
            type: 'content_rejected'
          })
        }
        break

      case 'request_revision':
        // Notify content creator and reviewers
        if (metadata?.originalCreatorId) {
          notificationsToSend.push({
            userId: metadata.originalCreatorId,
            type: 'content_revision_requested'
          })
        }
        notificationsToSend.push(
          { userId: 'reviewers', userRole: 'reviewer', type: 'content_revision_requested' }
        )
        break

      case 'publish':
        // Notify content creator and team
        if (metadata?.originalCreatorId) {
          notificationsToSend.push({
            userId: metadata.originalCreatorId,
            type: 'content_published'
          })
        }
        notificationsToSend.push(
          { userId: 'team', type: 'content_published' }
        )
        break

      case 'archive':
        // Notify content creator
        if (metadata?.originalCreatorId) {
          notificationsToSend.push({
            userId: metadata.originalCreatorId,
            type: 'content_archived'
          })
        }
        break
    }

    // Create and send notifications
    for (const recipient of notificationsToSend) {
      const notification = this.createNotification({
        type: recipient.type,
        contentId,
        contentTitle,
        action,
        fromStatus,
        toStatus,
        fromUserId,
        fromUserName,
        toUserRole: recipient.userRole,
        comment,
        metadata
      })

      // In a real implementation, you would:
      // 1. Save to database
      // 2. Send push notifications
      // 3. Send emails if configured
      // 4. Send to specific users based on role queries
      
      // For now, we'll just store in memory for demo purposes
      if (recipient.userId.startsWith('demo_user_')) {
        this.addNotification(recipient.userId, notification)
      }
    }
  }

  // Notify bulk action completion
  async notifyBulkAction({
    action,
    itemCount,
    fromUserId,
    fromUserName,
    successCount,
    failureCount,
    metadata
  }: {
    action: string
    itemCount: number
    fromUserId?: string
    fromUserName?: string
    successCount: number
    failureCount: number
    metadata?: Record<string, any>
  }): Promise<void> {
    if (fromUserId) {
      const notification = this.createNotification({
        type: 'bulk_action_completed',
        contentId: 'bulk',
        contentTitle: `${itemCount} items`,
        action: action as ApprovalAction,
        fromStatus: 'DRAFT' as ContentStatus,
        toStatus: 'APPROVED' as ContentStatus,
        fromUserId,
        fromUserName,
        metadata: {
          ...metadata,
          itemCount,
          successCount,
          failureCount
        }
      })

      this.addNotification(fromUserId, notification)
    }
  }
}

// Global notification service instance
export const notificationService = new NotificationService()

// Utility functions
export function getNotificationIcon(type: NotificationEventType): string {
  const iconMap: Record<NotificationEventType, string> = {
    content_submitted: '👁️',
    content_approved: '✅',
    content_rejected: '❌',
    content_revision_requested: '✏️',
    content_published: '🌐',
    content_archived: '📦',
    bulk_action_completed: '📊',
    workflow_comment_added: '💬'
  }
  return iconMap[type] || '📄'
}

export function getNotificationColor(priority: 'low' | 'medium' | 'high'): string {
  const colorMap = {
    low: 'bg-gray-100 text-gray-800',
    medium: 'bg-blue-100 text-blue-800',
    high: 'bg-red-100 text-red-800'
  }
  return colorMap[priority]
}

export function formatNotificationTime(date: Date): string {
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / (1000 * 60))
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  if (diffDays < 7) return `${diffDays}d ago`
  
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric'
  })
}