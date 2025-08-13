import { PrismaClient, AuditEventType, AuditEventCategory, AuditEntityType } from '@prisma/client'
import { addDays, subDays, isBefore } from 'date-fns'

export interface RetentionPolicyConfig {
  id?: string
  name: string
  description?: string
  isActive: boolean
  
  // Policy scope
  eventTypes?: AuditEventType[]
  eventCategories?: AuditEventCategory[]
  entityTypes?: AuditEntityType[]
  
  // Retention rules
  retentionDays: number
  anonymizeDays?: number // Days after which to anonymize personal data
  archiveDays?: number   // Days after which to archive logs
  
  // Conditions for more complex rules
  conditions?: {
    severities?: string[]
    userRoles?: string[]
    environments?: string[]
    hasPersonalData?: boolean
    customSql?: string
  }
  
  // Execution settings
  priority: number // Lower = higher priority
  dryRun?: boolean
}

export interface RetentionStats {
  totalLogs: number
  eligibleForDeletion: number
  eligibleForAnonymization: number
  eligibleForArchiving: number
  estimatedSpaceSaved: number // in bytes
  oldestLog?: Date
  newestLog?: Date
}

export interface RetentionExecutionResult {
  policyId: string
  policyName: string
  executed: boolean
  dryRun: boolean
  startTime: Date
  endTime: Date
  statistics: {
    logsProcessed: number
    logsDeleted: number
    logsAnonymized: number
    logsArchived: number
    spaceSaved: number
    errors: number
  }
  errors: string[]
}

export class AuditRetentionManager {
  private prisma: PrismaClient

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
  }

  /**
   * Create a new retention policy
   */
  async createPolicy(config: RetentionPolicyConfig): Promise<string> {
    const policy = await this.prisma.auditRetentionPolicy.create({
      data: {
        name: config.name,
        description: config.description,
        isActive: config.isActive,
        eventTypes: config.eventTypes ? JSON.stringify(config.eventTypes) : null,
        eventCategories: config.eventCategories ? JSON.stringify(config.eventCategories) : null,
        entityTypes: config.entityTypes ? JSON.stringify(config.entityTypes) : null,
        retentionDays: config.retentionDays,
        anonymizeDays: config.anonymizeDays,
        archiveDays: config.archiveDays,
        conditions: config.conditions ? JSON.stringify(config.conditions) : null,
        priority: config.priority
      }
    })

    return policy.id
  }

  /**
   * Update an existing retention policy
   */
  async updatePolicy(id: string, config: Partial<RetentionPolicyConfig>): Promise<void> {
    await this.prisma.auditRetentionPolicy.update({
      where: { id },
      data: {
        name: config.name,
        description: config.description,
        isActive: config.isActive,
        eventTypes: config.eventTypes ? JSON.stringify(config.eventTypes) : undefined,
        eventCategories: config.eventCategories ? JSON.stringify(config.eventCategories) : undefined,
        entityTypes: config.entityTypes ? JSON.stringify(config.entityTypes) : undefined,
        retentionDays: config.retentionDays,
        anonymizeDays: config.anonymizeDays,
        archiveDays: config.archiveDays,
        conditions: config.conditions ? JSON.stringify(config.conditions) : undefined,
        priority: config.priority
      }
    })
  }

  /**
   * Delete a retention policy
   */
  async deletePolicy(id: string): Promise<void> {
    await this.prisma.auditRetentionPolicy.delete({
      where: { id }
    })
  }

  /**
   * Get all retention policies
   */
  async getPolicies(activeOnly = false): Promise<RetentionPolicyConfig[]> {
    const policies = await this.prisma.auditRetentionPolicy.findMany({
      where: activeOnly ? { isActive: true } : undefined,
      orderBy: { priority: 'asc' }
    })

    return policies.map(policy => ({
      id: policy.id,
      name: policy.name,
      description: policy.description || undefined,
      isActive: policy.isActive,
      eventTypes: policy.eventTypes ? JSON.parse(policy.eventTypes) : undefined,
      eventCategories: policy.eventCategories ? JSON.parse(policy.eventCategories) : undefined,
      entityTypes: policy.entityTypes ? JSON.parse(policy.entityTypes) : undefined,
      retentionDays: policy.retentionDays,
      anonymizeDays: policy.anonymizeDays || undefined,
      archiveDays: policy.archiveDays || undefined,
      conditions: policy.conditions ? JSON.parse(policy.conditions) : undefined,
      priority: policy.priority
    }))
  }

  /**
   * Analyze what would happen if retention policies were executed
   */
  async analyzeRetention(policyId?: string): Promise<RetentionStats> {
    const policies = policyId 
      ? await this.getPolicies().then(p => p.filter(policy => policy.id === policyId))
      : await this.getPolicies(true)

    let totalEligibleForDeletion = 0
    let totalEligibleForAnonymization = 0
    let totalEligibleForArchiving = 0

    for (const policy of policies) {
      const whereClause = this.buildWhereClause(policy)
      
      // Check deletion eligibility
      if (policy.retentionDays) {
        const deletionDate = subDays(new Date(), policy.retentionDays)
        const deletionCount = await this.prisma.auditLog.count({
          where: {
            ...whereClause,
            createdAt: { lt: deletionDate }
          }
        })
        totalEligibleForDeletion += deletionCount
      }

      // Check anonymization eligibility
      if (policy.anonymizeDays) {
        const anonymizationDate = subDays(new Date(), policy.anonymizeDays)
        const anonymizationCount = await this.prisma.auditLog.count({
          where: {
            ...whereClause,
            createdAt: { lt: anonymizationDate },
            isPersonalData: true,
            anonymizedAt: null
          }
        })
        totalEligibleForAnonymization += anonymizationCount
      }

      // Check archiving eligibility
      if (policy.archiveDays) {
        const archiveDate = subDays(new Date(), policy.archiveDays)
        const archiveCount = await this.prisma.auditLog.count({
          where: {
            ...whereClause,
            createdAt: { lt: archiveDate }
          }
        })
        totalEligibleForArchiving += archiveCount
      }
    }

    // Get overall statistics
    const totalLogs = await this.prisma.auditLog.count()
    const [oldestLog, newestLog] = await Promise.all([
      this.prisma.auditLog.findFirst({
        orderBy: { createdAt: 'asc' },
        select: { createdAt: true }
      }),
      this.prisma.auditLog.findFirst({
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true }
      })
    ])

    // Estimate space saved (rough calculation)
    const avgLogSize = 2048 // Estimated average size per log entry in bytes
    const estimatedSpaceSaved = totalEligibleForDeletion * avgLogSize

    return {
      totalLogs,
      eligibleForDeletion: totalEligibleForDeletion,
      eligibleForAnonymization: totalEligibleForAnonymization,
      eligibleForArchiving: totalEligibleForArchiving,
      estimatedSpaceSaved,
      oldestLog: oldestLog?.createdAt,
      newestLog: newestLog?.createdAt
    }
  }

  /**
   * Execute retention policies
   */
  async executeRetention(
    policyId?: string, 
    dryRun = false, 
    batchSize = 1000
  ): Promise<RetentionExecutionResult[]> {
    const policies = policyId 
      ? await this.getPolicies().then(p => p.filter(policy => policy.id === policyId))
      : await this.getPolicies(true)

    const results: RetentionExecutionResult[] = []

    for (const policy of policies) {
      const result = await this.executePolicy(policy, dryRun, batchSize)
      results.push(result)
    }

    return results
  }

  /**
   * Execute a single retention policy
   */
  private async executePolicy(
    policy: RetentionPolicyConfig, 
    dryRun: boolean,
    batchSize: number
  ): Promise<RetentionExecutionResult> {
    const startTime = new Date()
    const result: RetentionExecutionResult = {
      policyId: policy.id!,
      policyName: policy.name,
      executed: true,
      dryRun,
      startTime,
      endTime: startTime,
      statistics: {
        logsProcessed: 0,
        logsDeleted: 0,
        logsAnonymized: 0,
        logsArchived: 0,
        spaceSaved: 0,
        errors: 0
      },
      errors: []
    }

    try {
      const whereClause = this.buildWhereClause(policy)

      // 1. Handle anonymization first
      if (policy.anonymizeDays) {
        await this.executeAnonymization(policy, whereClause, dryRun, batchSize, result)
      }

      // 2. Handle archiving
      if (policy.archiveDays && policy.archiveDays < policy.retentionDays) {
        await this.executeArchiving(policy, whereClause, dryRun, batchSize, result)
      }

      // 3. Handle deletion last
      if (policy.retentionDays) {
        await this.executeDeletion(policy, whereClause, dryRun, batchSize, result)
      }

    } catch (error) {
      result.executed = false
      result.errors.push(`Policy execution failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
      result.statistics.errors++
    }

    result.endTime = new Date()
    return result
  }

  /**
   * Execute anonymization for a policy
   */
  private async executeAnonymization(
    policy: RetentionPolicyConfig,
    whereClause: any,
    dryRun: boolean,
    batchSize: number,
    result: RetentionExecutionResult
  ): Promise<void> {
    const anonymizationDate = subDays(new Date(), policy.anonymizeDays!)
    
    const anonymizeWhere = {
      ...whereClause,
      createdAt: { lt: anonymizationDate },
      isPersonalData: true,
      anonymizedAt: null
    }

    if (dryRun) {
      const count = await this.prisma.auditLog.count({ where: anonymizeWhere })
      result.statistics.logsAnonymized = count
      return
    }

    let processed = 0
    let hasMore = true

    while (hasMore) {
      const logs = await this.prisma.auditLog.findMany({
        where: anonymizeWhere,
        select: { id: true },
        take: batchSize
      })

      if (logs.length === 0) {
        hasMore = false
        continue
      }

      try {
        // Anonymize personal data fields
        await this.prisma.auditLog.updateMany({
          where: { id: { in: logs.map(log => log.id) } },
          data: {
            username: 'ANONYMIZED',
            userRole: 'ANONYMIZED',
            ipAddress: 'ANONYMIZED',
            userAgent: 'ANONYMIZED',
            oldValues: null,
            newValues: null,
            metadata: null,
            anonymizedAt: new Date()
          }
        })

        processed += logs.length
        result.statistics.logsAnonymized += logs.length
        result.statistics.logsProcessed += logs.length

      } catch (error) {
        result.errors.push(`Anonymization batch failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
        result.statistics.errors++
      }

      if (logs.length < batchSize) {
        hasMore = false
      }
    }
  }

  /**
   * Execute archiving for a policy
   */
  private async executeArchiving(
    policy: RetentionPolicyConfig,
    whereClause: any,
    dryRun: boolean,
    batchSize: number,
    result: RetentionExecutionResult
  ): Promise<void> {
    const archiveDate = subDays(new Date(), policy.archiveDays!)
    
    const archiveWhere = {
      ...whereClause,
      createdAt: { lt: archiveDate }
    }

    if (dryRun) {
      const count = await this.prisma.auditLog.count({ where: archiveWhere })
      result.statistics.logsArchived = count
      return
    }

    // For now, archiving just means marking the logs
    // In a production system, you'd export to cold storage
    let hasMore = true

    while (hasMore) {
      const logs = await this.prisma.auditLog.findMany({
        where: archiveWhere,
        select: { id: true },
        take: batchSize
      })

      if (logs.length === 0) {
        hasMore = false
        continue
      }

      try {
        // Mark as archived (you could export to external storage here)
        await this.prisma.auditLog.updateMany({
          where: { id: { in: logs.map(log => log.id) } },
          data: {
            // Add archived flag to metadata
            metadata: JSON.stringify({ archived: true, archivedAt: new Date() })
          }
        })

        result.statistics.logsArchived += logs.length
        result.statistics.logsProcessed += logs.length

      } catch (error) {
        result.errors.push(`Archiving batch failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
        result.statistics.errors++
      }

      if (logs.length < batchSize) {
        hasMore = false
      }
    }
  }

  /**
   * Execute deletion for a policy
   */
  private async executeDeletion(
    policy: RetentionPolicyConfig,
    whereClause: any,
    dryRun: boolean,
    batchSize: number,
    result: RetentionExecutionResult
  ): Promise<void> {
    const deletionDate = subDays(new Date(), policy.retentionDays)
    
    const deleteWhere = {
      ...whereClause,
      createdAt: { lt: deletionDate }
    }

    if (dryRun) {
      const count = await this.prisma.auditLog.count({ where: deleteWhere })
      result.statistics.logsDeleted = count
      result.statistics.spaceSaved = count * 2048 // Estimated size
      return
    }

    let hasMore = true

    while (hasMore) {
      const logs = await this.prisma.auditLog.findMany({
        where: deleteWhere,
        select: { id: true },
        take: batchSize
      })

      if (logs.length === 0) {
        hasMore = false
        continue
      }

      try {
        await this.prisma.auditLog.deleteMany({
          where: { id: { in: logs.map(log => log.id) } }
        })

        result.statistics.logsDeleted += logs.length
        result.statistics.logsProcessed += logs.length
        result.statistics.spaceSaved += logs.length * 2048 // Estimated size

      } catch (error) {
        result.errors.push(`Deletion batch failed: ${error instanceof Error ? error.message : 'Unknown error'}`)
        result.statistics.errors++
      }

      if (logs.length < batchSize) {
        hasMore = false
      }
    }
  }

  /**
   * Build where clause for a retention policy
   */
  private buildWhereClause(policy: RetentionPolicyConfig): any {
    const where: any = {}

    if (policy.eventTypes?.length) {
      where.eventType = { in: policy.eventTypes }
    }

    if (policy.eventCategories?.length) {
      where.eventCategory = { in: policy.eventCategories }
    }

    if (policy.entityTypes?.length) {
      where.entityType = { in: policy.entityTypes }
    }

    if (policy.conditions) {
      if (policy.conditions.severities?.length) {
        where.severity = { in: policy.conditions.severities }
      }

      if (policy.conditions.environments?.length) {
        where.environment = { in: policy.conditions.environments }
      }

      if (policy.conditions.hasPersonalData !== undefined) {
        where.isPersonalData = policy.conditions.hasPersonalData
      }
    }

    return where
  }

  /**
   * Create default retention policies
   */
  async createDefaultPolicies(): Promise<string[]> {
    const defaultPolicies: RetentionPolicyConfig[] = [
      {
        name: 'Security Events Retention',
        description: 'Retain security events for 2 years',
        isActive: true,
        eventCategories: ['SECURITY'],
        retentionDays: 730, // 2 years
        anonymizeDays: 90,  // 3 months
        priority: 10
      },
      {
        name: 'User Management Retention',
        description: 'Retain user management events for 1 year',
        isActive: true,
        eventCategories: ['USER_MANAGEMENT'],
        retentionDays: 365, // 1 year
        anonymizeDays: 30,  // 1 month
        priority: 20
      },
      {
        name: 'Content Management Retention',
        description: 'Retain content events for 6 months',
        isActive: true,
        eventCategories: ['CONTENT_MANAGEMENT'],
        retentionDays: 180, // 6 months
        anonymizeDays: 30,  // 1 month
        priority: 30
      },
      {
        name: 'System Administration Retention',
        description: 'Retain system events for 3 months',
        isActive: true,
        eventCategories: ['SYSTEM_ADMINISTRATION'],
        retentionDays: 90,  // 3 months
        anonymizeDays: 7,   // 1 week
        priority: 40
      },
      {
        name: 'Debug Logs Cleanup',
        description: 'Remove debug logs after 7 days',
        isActive: true,
        conditions: { severities: ['DEBUG'] },
        retentionDays: 7,   // 1 week
        priority: 50
      }
    ]

    const policyIds: string[] = []
    
    for (const policy of defaultPolicies) {
      try {
        const id = await this.createPolicy(policy)
        policyIds.push(id)
      } catch (error) {
        console.error(`Failed to create default policy "${policy.name}":`, error)
      }
    }

    return policyIds
  }
}

export default AuditRetentionManager