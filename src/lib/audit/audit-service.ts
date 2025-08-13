import { PrismaClient, AuditEventType, AuditEventCategory, AuditEntityType, AuditSeverity } from '@prisma/client'
import { nanoid } from 'nanoid'

export interface AuditContext {
  userId?: string
  username?: string
  userRole?: string
  sessionId?: string
  ipAddress?: string
  userAgent?: string
  referrer?: string
  requestId?: string
  hostname?: string
  environment?: string
  applicationVersion?: string
}

export interface AuditLogEntry {
  eventType: AuditEventType
  eventCategory: AuditEventCategory
  entityType: AuditEntityType
  entityId: string
  action: string
  description: string
  oldValues?: Record<string, any>
  newValues?: Record<string, any>
  changedFields?: string[]
  metadata?: Record<string, any>
  tags?: string[]
  severity?: AuditSeverity
  isPersonalData?: boolean
  retentionDays?: number
  duration?: number
}

export interface AuditSessionInfo {
  sessionId: string
  userId?: string
  username?: string
  userRole?: string
  ipAddress?: string
  userAgent?: string
  referrer?: string
  metadata?: Record<string, any>
}

export class AuditService {
  private prisma: PrismaClient
  private defaultContext: Partial<AuditContext>

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
    this.defaultContext = {
      environment: process.env.NODE_ENV || 'development',
      applicationVersion: process.env.APP_VERSION || '1.0.0',
      hostname: process.env.HOSTNAME || 'localhost'
    }
  }

  /**
   * Log an audit event
   */
  async log(entry: AuditLogEntry, context?: AuditContext): Promise<void> {
    try {
      const fullContext = { ...this.defaultContext, ...context }
      const requestId = fullContext.requestId || nanoid()

      await this.prisma.auditLog.create({
        data: {
          eventType: entry.eventType,
          eventCategory: entry.eventCategory,
          entityType: entry.entityType,
          entityId: entry.entityId,
          action: entry.action,
          description: entry.description,
          
          // User and session tracking
          userId: fullContext.userId,
          username: fullContext.username,
          userRole: fullContext.userRole,
          sessionId: fullContext.sessionId,
          
          // Request context
          ipAddress: fullContext.ipAddress,
          userAgent: fullContext.userAgent,
          referrer: fullContext.referrer,
          requestId,
          
          // Change tracking
          oldValues: entry.oldValues ? JSON.stringify(entry.oldValues) : null,
          newValues: entry.newValues ? JSON.stringify(entry.newValues) : null,
          changedFields: entry.changedFields ? JSON.stringify(entry.changedFields) : null,
          
          // System context
          hostname: fullContext.hostname,
          environment: fullContext.environment,
          applicationVersion: fullContext.applicationVersion,
          
          // Metadata and additional context
          metadata: entry.metadata ? JSON.stringify(entry.metadata) : null,
          tags: entry.tags ? JSON.stringify(entry.tags) : null,
          severity: entry.severity || AuditSeverity.INFO,
          
          // Privacy and retention
          isPersonalData: entry.isPersonalData || false,
          retentionDays: entry.retentionDays,
          
          // Performance tracking
          duration: entry.duration
        }
      })

      // Update session if sessionId is provided
      if (fullContext.sessionId) {
        await this.updateSession(fullContext.sessionId, {
          lastActivity: new Date(),
          actionsCount: { increment: 1 }
        })
      }
    } catch (error) {
      // Log audit failures to console but don't throw to avoid breaking application flow
      console.error('Failed to write audit log:', error)
    }
  }

  /**
   * Start a new audit session
   */
  async startSession(sessionInfo: AuditSessionInfo): Promise<void> {
    try {
      await this.prisma.auditSession.upsert({
        where: { sessionId: sessionInfo.sessionId },
        create: {
          sessionId: sessionInfo.sessionId,
          userId: sessionInfo.userId,
          username: sessionInfo.username,
          userRole: sessionInfo.userRole,
          ipAddress: sessionInfo.ipAddress,
          userAgent: sessionInfo.userAgent,
          referrer: sessionInfo.referrer,
          metadata: sessionInfo.metadata ? JSON.stringify(sessionInfo.metadata) : null,
          isActive: true,
          startedAt: new Date(),
          lastActivity: new Date()
        },
        update: {
          userId: sessionInfo.userId,
          username: sessionInfo.username,
          userRole: sessionInfo.userRole,
          isActive: true,
          lastActivity: new Date(),
          endedAt: null
        }
      })
    } catch (error) {
      console.error('Failed to start audit session:', error)
    }
  }

  /**
   * End an audit session
   */
  async endSession(sessionId: string): Promise<void> {
    try {
      const session = await this.prisma.auditSession.findUnique({
        where: { sessionId }
      })

      if (session) {
        const duration = Math.floor((Date.now() - session.startedAt.getTime()) / 1000)
        
        await this.prisma.auditSession.update({
          where: { sessionId },
          data: {
            isActive: false,
            endedAt: new Date(),
            duration
          }
        })
      }
    } catch (error) {
      console.error('Failed to end audit session:', error)
    }
  }

  /**
   * Update session activity
   */
  private async updateSession(sessionId: string, updates: any): Promise<void> {
    try {
      await this.prisma.auditSession.updateMany({
        where: { 
          sessionId,
          isActive: true 
        },
        data: updates
      })
    } catch (error) {
      console.error('Failed to update audit session:', error)
    }
  }

  /**
   * Helper methods for common audit actions
   */

  // Create operations
  async logCreate(
    entityType: AuditEntityType, 
    entityId: string, 
    data: Record<string, any>,
    context?: AuditContext,
    options?: { category?: AuditEventCategory; metadata?: Record<string, any> }
  ): Promise<void> {
    await this.log({
      eventType: AuditEventType.CREATE,
      eventCategory: options?.category || this.getDefaultCategory(entityType),
      entityType,
      entityId,
      action: 'created',
      description: `${entityType.toLowerCase()} created`,
      newValues: data,
      metadata: options?.metadata,
      severity: AuditSeverity.INFO
    }, context)
  }

  // Update operations
  async logUpdate(
    entityType: AuditEntityType,
    entityId: string,
    oldData: Record<string, any>,
    newData: Record<string, any>,
    context?: AuditContext,
    options?: { category?: AuditEventCategory; metadata?: Record<string, any> }
  ): Promise<void> {
    const changedFields = this.getChangedFields(oldData, newData)
    
    await this.log({
      eventType: AuditEventType.UPDATE,
      eventCategory: options?.category || this.getDefaultCategory(entityType),
      entityType,
      entityId,
      action: 'updated',
      description: `${entityType.toLowerCase()} updated: ${changedFields.join(', ')}`,
      oldValues: oldData,
      newValues: newData,
      changedFields,
      metadata: options?.metadata,
      severity: AuditSeverity.INFO
    }, context)
  }

  // Delete operations
  async logDelete(
    entityType: AuditEntityType,
    entityId: string,
    data: Record<string, any>,
    context?: AuditContext,
    options?: { category?: AuditEventCategory; metadata?: Record<string, any> }
  ): Promise<void> {
    await this.log({
      eventType: AuditEventType.DELETE,
      eventCategory: options?.category || this.getDefaultCategory(entityType),
      entityType,
      entityId,
      action: 'deleted',
      description: `${entityType.toLowerCase()} deleted`,
      oldValues: data,
      metadata: options?.metadata,
      severity: AuditSeverity.NOTICE
    }, context)
  }

  // View operations
  async logView(
    entityType: AuditEntityType,
    entityId: string,
    context?: AuditContext,
    options?: { category?: AuditEventCategory; metadata?: Record<string, any> }
  ): Promise<void> {
    await this.log({
      eventType: AuditEventType.VIEW,
      eventCategory: options?.category || this.getDefaultCategory(entityType),
      entityType,
      entityId,
      action: 'viewed',
      description: `${entityType.toLowerCase()} viewed`,
      metadata: options?.metadata,
      severity: AuditSeverity.DEBUG
    }, context)
  }

  // Approval operations
  async logApproval(
    entityType: AuditEntityType,
    entityId: string,
    approvalAction: 'approve' | 'reject' | 'request_changes',
    comment?: string,
    context?: AuditContext,
    options?: { metadata?: Record<string, any> }
  ): Promise<void> {
    const eventType = approvalAction === 'approve' ? AuditEventType.APPROVE : AuditEventType.REJECT
    
    await this.log({
      eventType,
      eventCategory: AuditEventCategory.APPROVAL_WORKFLOW,
      entityType,
      entityId,
      action: approvalAction,
      description: `${entityType.toLowerCase()} ${approvalAction}${comment ? `: ${comment}` : ''}`,
      metadata: { comment, ...options?.metadata },
      severity: AuditSeverity.INFO
    }, context)
  }

  // Security events
  async logSecurityEvent(
    action: string,
    description: string,
    context?: AuditContext,
    options?: { 
      severity?: AuditSeverity
      entityType?: AuditEntityType
      entityId?: string
      metadata?: Record<string, any>
    }
  ): Promise<void> {
    await this.log({
      eventType: AuditEventType.SECURITY_EVENT,
      eventCategory: AuditEventCategory.SECURITY,
      entityType: options?.entityType || AuditEntityType.SYSTEM,
      entityId: options?.entityId || 'system',
      action,
      description,
      metadata: options?.metadata,
      severity: options?.severity || AuditSeverity.WARNING
    }, context)
  }

  // API calls
  async logApiCall(
    endpoint: string,
    method: string,
    statusCode: number,
    duration: number,
    context?: AuditContext,
    options?: { metadata?: Record<string, any> }
  ): Promise<void> {
    const severity = statusCode >= 400 ? AuditSeverity.ERROR : AuditSeverity.DEBUG
    
    await this.log({
      eventType: AuditEventType.API_CALL,
      eventCategory: AuditEventCategory.API_ACCESS,
      entityType: AuditEntityType.SYSTEM,
      entityId: 'api',
      action: `${method} ${endpoint}`,
      description: `API call: ${method} ${endpoint} - ${statusCode}`,
      metadata: { endpoint, method, statusCode, ...options?.metadata },
      severity,
      duration
    }, context)
  }

  // Bulk operations
  async logBulkAction(
    action: string,
    entityType: AuditEntityType,
    entityIds: string[],
    context?: AuditContext,
    options?: { 
      category?: AuditEventCategory
      metadata?: Record<string, any>
    }
  ): Promise<void> {
    await this.log({
      eventType: AuditEventType.BULK_ACTION,
      eventCategory: options?.category || this.getDefaultCategory(entityType),
      entityType,
      entityId: 'bulk',
      action,
      description: `Bulk ${action} on ${entityIds.length} ${entityType.toLowerCase()}(s)`,
      metadata: { entityIds, count: entityIds.length, ...options?.metadata },
      severity: AuditSeverity.INFO
    }, context)
  }

  /**
   * Utility methods
   */
  private getChangedFields(oldData: Record<string, any>, newData: Record<string, any>): string[] {
    const changedFields: string[] = []
    
    // Check for changed and new fields
    for (const key in newData) {
      if (JSON.stringify(oldData[key]) !== JSON.stringify(newData[key])) {
        changedFields.push(key)
      }
    }
    
    // Check for removed fields
    for (const key in oldData) {
      if (!(key in newData)) {
        changedFields.push(key)
      }
    }
    
    return changedFields
  }

  private getDefaultCategory(entityType: AuditEntityType): AuditEventCategory {
    const categoryMap: Record<AuditEntityType, AuditEventCategory> = {
      [AuditEntityType.USER]: AuditEventCategory.USER_MANAGEMENT,
      [AuditEntityType.BRAND]: AuditEventCategory.BRAND_MANAGEMENT,
      [AuditEntityType.CAMPAIGN]: AuditEventCategory.CAMPAIGN_MANAGEMENT,
      [AuditEntityType.JOURNEY]: AuditEventCategory.CAMPAIGN_MANAGEMENT,
      [AuditEntityType.CONTENT]: AuditEventCategory.CONTENT_MANAGEMENT,
      [AuditEntityType.TEMPLATE]: AuditEventCategory.CONTENT_MANAGEMENT,
      [AuditEntityType.COMMENT]: AuditEventCategory.TEAM_COLLABORATION,
      [AuditEntityType.APPROVAL_WORKFLOW]: AuditEventCategory.APPROVAL_WORKFLOW,
      [AuditEntityType.APPROVAL_REQUEST]: AuditEventCategory.APPROVAL_WORKFLOW,
      [AuditEntityType.APPROVAL_ACTION]: AuditEventCategory.APPROVAL_WORKFLOW,
      [AuditEntityType.ANALYTICS]: AuditEventCategory.ANALYTICS,
      [AuditEntityType.EXPORT]: AuditEventCategory.DATA_EXPORT,
      [AuditEntityType.SESSION]: AuditEventCategory.USER_MANAGEMENT,
      [AuditEntityType.SYSTEM]: AuditEventCategory.SYSTEM_ADMINISTRATION,
      [AuditEntityType.TEAM]: AuditEventCategory.USER_MANAGEMENT,
      [AuditEntityType.ROLE]: AuditEventCategory.USER_MANAGEMENT,
      [AuditEntityType.PERMISSION]: AuditEventCategory.USER_MANAGEMENT,
      [AuditEntityType.INTEGRATION]: AuditEventCategory.INTEGRATION,
      [AuditEntityType.WEBHOOK]: AuditEventCategory.INTEGRATION,
      [AuditEntityType.API_KEY]: AuditEventCategory.SECURITY,
      [AuditEntityType.NOTIFICATION]: AuditEventCategory.NOTIFICATION,
      [AuditEntityType.FILE]: AuditEventCategory.FILE_MANAGEMENT,
      [AuditEntityType.ASSET]: AuditEventCategory.FILE_MANAGEMENT
    }
    
    return categoryMap[entityType] || AuditEventCategory.SYSTEM_ADMINISTRATION
  }
}

// Singleton instance
let auditService: AuditService | null = null

export function getAuditService(prisma: PrismaClient): AuditService {
  if (!auditService) {
    auditService = new AuditService(prisma)
  }
  return auditService
}

export default AuditService