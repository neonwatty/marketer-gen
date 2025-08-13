import { NotificationType, NotificationCategory, NotificationPriority } from '@prisma/client'
import { NotificationData, NotificationService } from './notification-service'

/**
 * Helper functions for creating common notification types
 */

export class NotificationHelpers {
  constructor(private notificationService: NotificationService) {}

  /**
   * Send a mention notification
   */
  async sendMentionNotification(data: {
    recipientId: string
    mentionedById: string
    mentionedByName: string
    contextType: string
    contextId: string
    contextTitle: string
    messagePreview: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.MENTION,
      category: NotificationCategory.COLLABORATION,
      priority: NotificationPriority.HIGH,
      title: `${data.mentionedByName} mentioned you`,
      message: `${data.mentionedByName} mentioned you in ${data.contextTitle}: "${data.messagePreview}"`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.mentionedById,
      senderName: data.mentionedByName,
      entityType: data.contextType,
      entityId: data.contextId,
      metadata: {
        messagePreview: data.messagePreview,
        contextTitle: data.contextTitle
      },
      groupKey: `mention_${data.contextType}_${data.contextId}`
    })
  }

  /**
   * Send assignment notification
   */
  async sendAssignmentNotification(data: {
    recipientId: string
    assignedById: string
    assignedByName: string
    taskTitle: string
    taskType: string
    taskId: string
    dueDate?: Date
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.ASSIGNMENT,
      category: NotificationCategory.COLLABORATION,
      priority: NotificationPriority.HIGH,
      title: `New assignment: ${data.taskTitle}`,
      message: `${data.assignedByName} assigned you to ${data.taskTitle}${data.dueDate ? ` (due ${data.dueDate.toLocaleDateString()})` : ''}`,
      actionText: 'View Task',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.assignedById,
      senderName: data.assignedByName,
      entityType: data.taskType,
      entityId: data.taskId,
      metadata: {
        dueDate: data.dueDate,
        taskTitle: data.taskTitle
      }
    })
  }

  /**
   * Send approval request notification
   */
  async sendApprovalRequestNotification(data: {
    recipientId: string
    requesterId: string
    requesterName: string
    contentTitle: string
    contentType: string
    contentId: string
    workflowName: string
    stageName: string
    dueDate?: Date
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.APPROVAL_REQUEST,
      category: NotificationCategory.APPROVAL,
      priority: NotificationPriority.HIGH,
      title: `Approval needed: ${data.contentTitle}`,
      message: `${data.requesterName} submitted "${data.contentTitle}" for approval in ${data.workflowName} (${data.stageName})`,
      actionText: 'Review',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.requesterId,
      senderName: data.requesterName,
      entityType: data.contentType,
      entityId: data.contentId,
      metadata: {
        workflowName: data.workflowName,
        stageName: data.stageName,
        dueDate: data.dueDate
      },
      expiresAt: data.dueDate
    })
  }

  /**
   * Send approval response notification
   */
  async sendApprovalResponseNotification(data: {
    recipientId: string
    approverId: string
    approverName: string
    contentTitle: string
    contentType: string
    contentId: string
    action: 'approved' | 'rejected' | 'requested_changes'
    comment?: string
    actionUrl: string
  }): Promise<string> {
    const actionText = {
      approved: 'approved',
      rejected: 'rejected',
      requested_changes: 'requested changes for'
    }[data.action]

    const priority = data.action === 'approved' ? NotificationPriority.MEDIUM : NotificationPriority.HIGH

    return await this.notificationService.createNotification({
      type: NotificationType.APPROVAL_RESPONSE,
      category: NotificationCategory.APPROVAL,
      priority,
      title: `${data.contentTitle} ${actionText}`,
      message: `${data.approverName} ${actionText} "${data.contentTitle}"${data.comment ? `: ${data.comment}` : ''}`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.approverId,
      senderName: data.approverName,
      entityType: data.contentType,
      entityId: data.contentId,
      metadata: {
        action: data.action,
        comment: data.comment
      }
    })
  }

  /**
   * Send comment notification
   */
  async sendCommentNotification(data: {
    recipientId: string
    commenterId: string
    commenterName: string
    commentPreview: string
    entityTitle: string
    entityType: string
    entityId: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.COMMENT,
      category: NotificationCategory.COLLABORATION,
      priority: NotificationPriority.MEDIUM,
      title: `New comment on ${data.entityTitle}`,
      message: `${data.commenterName} commented: "${data.commentPreview}"`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.commenterId,
      senderName: data.commenterName,
      entityType: data.entityType,
      entityId: data.entityId,
      metadata: {
        commentPreview: data.commentPreview,
        entityTitle: data.entityTitle
      },
      groupKey: `comment_${data.entityType}_${data.entityId}`
    })
  }

  /**
   * Send content update notification
   */
  async sendContentUpdateNotification(data: {
    recipientId: string
    updaterId: string
    updaterName: string
    contentTitle: string
    contentType: string
    contentId: string
    updateType: string
    changedFields?: string[]
    actionUrl: string
  }): Promise<string> {
    const fieldsText = data.changedFields?.length ? ` (${data.changedFields.join(', ')})` : ''

    return await this.notificationService.createNotification({
      type: NotificationType.CONTENT_UPDATE,
      category: NotificationCategory.CONTENT,
      priority: NotificationPriority.LOW,
      title: `${data.contentTitle} updated`,
      message: `${data.updaterName} ${data.updateType} "${data.contentTitle}"${fieldsText}`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.updaterId,
      senderName: data.updaterName,
      entityType: data.contentType,
      entityId: data.contentId,
      metadata: {
        updateType: data.updateType,
        changedFields: data.changedFields
      },
      groupKey: `content_update_${data.contentId}`
    })
  }

  /**
   * Send campaign update notification
   */
  async sendCampaignUpdateNotification(data: {
    recipientId: string
    updaterId: string
    updaterName: string
    campaignTitle: string
    campaignId: string
    updateType: string
    newStatus?: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.CAMPAIGN_UPDATE,
      category: NotificationCategory.MARKETING,
      priority: NotificationPriority.MEDIUM,
      title: `Campaign ${data.updateType}: ${data.campaignTitle}`,
      message: `${data.updaterName} ${data.updateType} "${data.campaignTitle}"${data.newStatus ? ` (${data.newStatus})` : ''}`,
      actionText: 'View Campaign',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.updaterId,
      senderName: data.updaterName,
      entityType: 'campaign',
      entityId: data.campaignId,
      metadata: {
        updateType: data.updateType,
        newStatus: data.newStatus
      },
      groupKey: `campaign_update_${data.campaignId}`
    })
  }

  /**
   * Send deadline reminder notification
   */
  async sendDeadlineReminderNotification(data: {
    recipientId: string
    taskTitle: string
    taskType: string
    taskId: string
    dueDate: Date
    timeUntilDue: string
    actionUrl: string
  }): Promise<string> {
    const priority = data.timeUntilDue.includes('hour') ? NotificationPriority.URGENT : NotificationPriority.HIGH

    return await this.notificationService.createNotification({
      type: NotificationType.DEADLINE_REMINDER,
      category: NotificationCategory.COLLABORATION,
      priority,
      title: `Deadline reminder: ${data.taskTitle}`,
      message: `"${data.taskTitle}" is due ${data.timeUntilDue} (${data.dueDate.toLocaleDateString()})`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      entityType: data.taskType,
      entityId: data.taskId,
      metadata: {
        dueDate: data.dueDate,
        timeUntilDue: data.timeUntilDue
      }
    })
  }

  /**
   * Send team invitation notification
   */
  async sendTeamInvitationNotification(data: {
    recipientId: string
    inviterId: string
    inviterName: string
    teamName: string
    role: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.TEAM_INVITATION,
      category: NotificationCategory.ADMINISTRATIVE,
      priority: NotificationPriority.HIGH,
      title: `Team invitation: ${data.teamName}`,
      message: `${data.inviterName} invited you to join "${data.teamName}" as ${data.role}`,
      actionText: 'View Invitation',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.inviterId,
      senderName: data.inviterName,
      metadata: {
        teamName: data.teamName,
        role: data.role
      }
    })
  }

  /**
   * Send role change notification
   */
  async sendRoleChangeNotification(data: {
    recipientId: string
    changedById: string
    changedByName: string
    oldRole: string
    newRole: string
    teamName?: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.ROLE_CHANGE,
      category: NotificationCategory.ADMINISTRATIVE,
      priority: NotificationPriority.MEDIUM,
      title: 'Role updated',
      message: `${data.changedByName} changed your role from ${data.oldRole} to ${data.newRole}${data.teamName ? ` in ${data.teamName}` : ''}`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      senderId: data.changedById,
      senderName: data.changedByName,
      metadata: {
        oldRole: data.oldRole,
        newRole: data.newRole,
        teamName: data.teamName
      }
    })
  }

  /**
   * Send system alert notification
   */
  async sendSystemAlertNotification(data: {
    recipientId: string
    alertTitle: string
    alertMessage: string
    severity: 'info' | 'warning' | 'error'
    actionUrl?: string
    actionText?: string
  }): Promise<string> {
    const priorityMap = {
      info: NotificationPriority.LOW,
      warning: NotificationPriority.MEDIUM,
      error: NotificationPriority.HIGH
    }

    return await this.notificationService.createNotification({
      type: NotificationType.SYSTEM_ALERT,
      category: NotificationCategory.SYSTEM,
      priority: priorityMap[data.severity],
      title: data.alertTitle,
      message: data.alertMessage,
      actionText: data.actionText,
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      metadata: {
        severity: data.severity
      }
    })
  }

  /**
   * Send security alert notification
   */
  async sendSecurityAlertNotification(data: {
    recipientId: string
    alertTitle: string
    alertMessage: string
    threatLevel: 'low' | 'medium' | 'high' | 'critical'
    actionUrl?: string
  }): Promise<string> {
    const priorityMap = {
      low: NotificationPriority.LOW,
      medium: NotificationPriority.MEDIUM,
      high: NotificationPriority.HIGH,
      critical: NotificationPriority.URGENT
    }

    return await this.notificationService.createNotification({
      type: NotificationType.SECURITY_ALERT,
      category: NotificationCategory.SECURITY,
      priority: priorityMap[data.threatLevel],
      title: data.alertTitle,
      message: data.alertMessage,
      actionText: 'Review',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      metadata: {
        threatLevel: data.threatLevel
      },
      channels: {
        inApp: true,
        email: true,
        push: data.threatLevel === 'critical',
        desktop: data.threatLevel === 'critical'
      }
    })
  }

  /**
   * Send export ready notification
   */
  async sendExportReadyNotification(data: {
    recipientId: string
    exportType: string
    fileName: string
    downloadUrl: string
    expiresAt?: Date
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.EXPORT_READY,
      category: NotificationCategory.REPORTS,
      priority: NotificationPriority.MEDIUM,
      title: `Export ready: ${data.exportType}`,
      message: `Your ${data.exportType} export "${data.fileName}" is ready for download`,
      actionText: 'Download',
      actionUrl: data.downloadUrl,
      recipientId: data.recipientId,
      metadata: {
        exportType: data.exportType,
        fileName: data.fileName
      },
      expiresAt: data.expiresAt
    })
  }

  /**
   * Send report ready notification
   */
  async sendReportReadyNotification(data: {
    recipientId: string
    reportName: string
    reportType: string
    reportUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.REPORT_READY,
      category: NotificationCategory.REPORTS,
      priority: NotificationPriority.MEDIUM,
      title: `Report ready: ${data.reportName}`,
      message: `Your ${data.reportType} report "${data.reportName}" has been generated`,
      actionText: 'View Report',
      actionUrl: data.reportUrl,
      recipientId: data.recipientId,
      metadata: {
        reportType: data.reportType
      }
    })
  }

  /**
   * Send workflow complete notification
   */
  async sendWorkflowCompleteNotification(data: {
    recipientId: string
    workflowName: string
    itemTitle: string
    itemType: string
    itemId: string
    finalStatus: string
    actionUrl: string
  }): Promise<string> {
    return await this.notificationService.createNotification({
      type: NotificationType.WORKFLOW_COMPLETE,
      category: NotificationCategory.APPROVAL,
      priority: NotificationPriority.MEDIUM,
      title: `Workflow complete: ${data.itemTitle}`,
      message: `"${data.itemTitle}" has completed the ${data.workflowName} workflow (${data.finalStatus})`,
      actionText: 'View',
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      entityType: data.itemType,
      entityId: data.itemId,
      metadata: {
        workflowName: data.workflowName,
        finalStatus: data.finalStatus
      }
    })
  }

  /**
   * Send bulk action complete notification
   */
  async sendBulkActionCompleteNotification(data: {
    recipientId: string
    actionType: string
    itemCount: number
    successCount: number
    failureCount: number
    actionUrl?: string
  }): Promise<string> {
    const hasFailures = data.failureCount > 0
    const priority = hasFailures ? NotificationPriority.MEDIUM : NotificationPriority.LOW

    return await this.notificationService.createNotification({
      type: NotificationType.BULK_ACTION_COMPLETE,
      category: NotificationCategory.SYSTEM,
      priority,
      title: `Bulk ${data.actionType} complete`,
      message: `${data.actionType} completed for ${data.successCount}/${data.itemCount} items${hasFailures ? ` (${data.failureCount} failed)` : ''}`,
      actionText: data.actionUrl ? 'View Results' : undefined,
      actionUrl: data.actionUrl,
      recipientId: data.recipientId,
      metadata: {
        actionType: data.actionType,
        itemCount: data.itemCount,
        successCount: data.successCount,
        failureCount: data.failureCount
      }
    })
  }
}

export default NotificationHelpers