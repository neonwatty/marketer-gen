import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { getNotificationService } from '@/lib/notifications/notification-service'
import { NotificationHelpers } from '@/lib/notifications/notification-helpers'
import { NotificationType, NotificationCategory, NotificationPriority } from '@prisma/client'

const prisma = new PrismaClient()

export async function POST(request: NextRequest) {
  try {
    const { userId, type, channel } = await request.json()

    if (!userId) {
      return NextResponse.json(
        { error: 'User ID is required' },
        { status: 400 }
      )
    }

    const notificationService = getNotificationService(prisma)
    const notificationHelpers = new NotificationHelpers(notificationService)

    let notificationId: string

    switch (type) {
      case 'mention':
        notificationId = await notificationHelpers.sendMentionNotification({
          recipientId: userId,
          mentionedById: 'test_user',
          mentionedByName: 'Test User',
          contextType: 'campaign',
          contextId: 'test_campaign',
          contextTitle: 'Test Campaign',
          messagePreview: 'This is a test mention notification',
          actionUrl: '/campaigns/test_campaign'
        })
        break

      case 'comment':
        notificationId = await notificationHelpers.sendCommentNotification({
          recipientId: userId,
          commenterId: 'test_user',
          commenterName: 'Test User',
          commentPreview: 'This is a test comment notification',
          entityTitle: 'Test Campaign',
          entityType: 'campaign',
          entityId: 'test_campaign',
          actionUrl: '/campaigns/test_campaign#comments'
        })
        break

      case 'assignment':
        notificationId = await notificationHelpers.sendAssignmentNotification({
          recipientId: userId,
          assignedById: 'test_user',
          assignedByName: 'Test User',
          taskTitle: 'Test Assignment',
          taskType: 'task',
          taskId: 'test_task',
          dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
          actionUrl: '/tasks/test_task'
        })
        break

      case 'approval':
        notificationId = await notificationHelpers.sendApprovalRequestNotification({
          recipientId: userId,
          requesterId: 'test_user',
          requesterName: 'Test User',
          contentTitle: 'Test Content',
          contentType: 'content',
          contentId: 'test_content',
          workflowName: 'Content Review',
          stageName: 'Final Review',
          actionUrl: '/content/test_content/review'
        })
        break

      case 'security':
        notificationId = await notificationHelpers.sendSecurityAlertNotification({
          recipientId: userId,
          alertTitle: 'Test Security Alert',
          alertMessage: 'This is a test security notification to verify your notification settings',
          threatLevel: 'low',
          actionUrl: '/security/sessions'
        })
        break

      default:
        // Generic test notification
        notificationId = await notificationService.createNotification({
          type: NotificationType.SYSTEM_ALERT,
          category: NotificationCategory.SYSTEM,
          priority: NotificationPriority.LOW,
          title: `Test ${channel} notification`,
          message: `This is a test ${channel} notification to verify your notification settings are working correctly.`,
          actionText: 'View Dashboard',
          actionUrl: '/dashboard',
          recipientId: userId,
          channels: {
            inApp: channel === 'in-app' || channel === 'all',
            email: channel === 'email' || channel === 'all',
            push: channel === 'push' || channel === 'all',
            desktop: channel === 'desktop' || channel === 'all'
          }
        })
        break
    }

    return NextResponse.json({ 
      success: true, 
      notificationId,
      message: `Test ${type || 'notification'} sent via ${channel}` 
    })
  } catch (error) {
    console.error('Error sending test notification:', error)
    return NextResponse.json(
      { error: 'Failed to send test notification' },
      { status: 500 }
    )
  }
}