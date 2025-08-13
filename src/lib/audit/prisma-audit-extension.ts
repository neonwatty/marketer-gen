import { Prisma, PrismaClient, AuditEntityType, AuditEventType } from '@prisma/client'
import { getAuditService, AuditContext } from './audit-service'

// Map Prisma model names to audit entity types
const MODEL_TO_ENTITY_MAP: Record<string, AuditEntityType> = {
  user: AuditEntityType.USER,
  brand: AuditEntityType.BRAND,
  campaign: AuditEntityType.CAMPAIGN,
  journey: AuditEntityType.JOURNEY,
  content: AuditEntityType.CONTENT,
  template: AuditEntityType.TEMPLATE,
  comment: AuditEntityType.COMMENT,
  approvalWorkflow: AuditEntityType.APPROVAL_WORKFLOW,
  approvalRequest: AuditEntityType.APPROVAL_REQUEST,
  approvalAction: AuditEntityType.APPROVAL_ACTION,
  analytics: AuditEntityType.ANALYTICS,
  journeyHistory: AuditEntityType.JOURNEY,
  commentReaction: AuditEntityType.COMMENT,
  approvalStage: AuditEntityType.APPROVAL_WORKFLOW,
  workflowTemplate: AuditEntityType.APPROVAL_WORKFLOW,
  workflowTemplateStage: AuditEntityType.APPROVAL_WORKFLOW
}

// Fields to exclude from audit logging (sensitive or unnecessary data)
const EXCLUDED_FIELDS = new Set([
  'password',
  'passwordHash',
  'salt',
  'token',
  'secret',
  'key',
  'createdAt',
  'updatedAt',
  'id'
])

// Models to exclude from audit logging
const EXCLUDED_MODELS = new Set([
  'auditLog',
  'auditSession',
  'auditRetentionPolicy',
  'auditReport',
  'auditExport'
])

export interface PrismaAuditOptions {
  enableCreate?: boolean
  enableUpdate?: boolean
  enableDelete?: boolean
  enableView?: boolean
  excludeModels?: string[]
  excludeFields?: string[]
  includeOldValues?: boolean
  auditContext?: AuditContext
}

const defaultOptions: PrismaAuditOptions = {
  enableCreate: true,
  enableUpdate: true,
  enableDelete: true,
  enableView: false, // Usually too verbose
  excludeModels: [],
  excludeFields: [],
  includeOldValues: true
}

/**
 * Prisma extension for automatic audit logging
 */
export function createPrismaAuditExtension(options: PrismaAuditOptions = {}) {
  const config = { ...defaultOptions, ...options }
  
  return Prisma.defineExtension({
    name: 'audit-trail',
    model: {
      $allModels: {
        async $audit<T extends Record<string, any>>(
          this: T,
          action: 'create' | 'update' | 'delete' | 'view',
          data?: any,
          where?: any
        ) {
          const model = (this as any).__typename || this.constructor.name
          const modelName = model.toLowerCase()
          
          // Skip excluded models
          if (EXCLUDED_MODELS.has(modelName) || config.excludeModels?.includes(modelName)) {
            return
          }
          
          // Skip if action is disabled
          const actionEnabled = {
            create: config.enableCreate,
            update: config.enableUpdate,
            delete: config.enableDelete,
            view: config.enableView
          }[action]
          
          if (!actionEnabled) return
          
          const entityType = MODEL_TO_ENTITY_MAP[modelName]
          if (!entityType) return
          
          const auditService = getAuditService(this as any)
          
          // Get entity ID
          let entityId = 'unknown'
          if (where?.id) {
            entityId = where.id
          } else if (data?.id) {
            entityId = data.id
          }
          
          // Prepare audit data
          const auditData = this.sanitizeAuditData(data || {}, config.excludeFields || [])
          
          // Log based on action type
          switch (action) {
            case 'create':
              await auditService.logCreate(
                entityType,
                entityId,
                auditData,
                config.auditContext,
                { metadata: { model: modelName } }
              )
              break
              
            case 'update':
              // For updates, we need the old values
              let oldData = {}
              if (config.includeOldValues && where?.id) {
                try {
                  const oldRecord = await (this as any).findUnique({ where })
                  oldData = this.sanitizeAuditData(oldRecord || {}, config.excludeFields || [])
                } catch (error) {
                  // If we can't fetch old data, continue without it
                }
              }
              
              await auditService.logUpdate(
                entityType,
                entityId,
                oldData,
                auditData,
                config.auditContext,
                { metadata: { model: modelName } }
              )
              break
              
            case 'delete':
              // For deletes, we need the data being deleted
              let deleteData = {}
              if (where?.id) {
                try {
                  const recordToDelete = await (this as any).findUnique({ where })
                  deleteData = this.sanitizeAuditData(recordToDelete || {}, config.excludeFields || [])
                } catch (error) {
                  // If we can't fetch data, continue without it
                }
              }
              
              await auditService.logDelete(
                entityType,
                entityId,
                deleteData,
                config.auditContext,
                { metadata: { model: modelName } }
              )
              break
              
            case 'view':
              await auditService.logView(
                entityType,
                entityId,
                config.auditContext,
                { metadata: { model: modelName } }
              )
              break
          }
        },
        
        sanitizeAuditData(data: Record<string, any>, excludeFields: string[] = []) {
          const sanitized: Record<string, any> = {}
          const allExcludedFields = new Set([...EXCLUDED_FIELDS, ...excludeFields])
          
          for (const [key, value] of Object.entries(data)) {
            if (!allExcludedFields.has(key)) {
              // Truncate very long strings
              if (typeof value === 'string' && value.length > 1000) {
                sanitized[key] = value.substring(0, 1000) + '...[truncated]'
              } else {
                sanitized[key] = value
              }
            }
          }
          
          return sanitized
        }
      }
    },
    query: {
      $allModels: {
        async create({ model, operation, args, query }) {
          const result = await query(args)
          
          // Audit the create operation
          if (!EXCLUDED_MODELS.has(model.toLowerCase())) {
            await (this as any).$audit('create', args.data, { id: result.id })
          }
          
          return result
        },
        
        async update({ model, operation, args, query }) {
          const result = await query(args)
          
          // Audit the update operation
          if (!EXCLUDED_MODELS.has(model.toLowerCase())) {
            await (this as any).$audit('update', args.data, args.where)
          }
          
          return result
        },
        
        async updateMany({ model, operation, args, query }) {
          const result = await query(args)
          
          // For updateMany, we can't easily track individual records
          // So we log a bulk operation
          if (!EXCLUDED_MODELS.has(model.toLowerCase())) {
            const entityType = MODEL_TO_ENTITY_MAP[model.toLowerCase()]
            if (entityType) {
              const auditService = getAuditService(this as any)
              await auditService.logBulkAction(
                'bulk_update',
                entityType,
                ['bulk'], // We don't know individual IDs
                defaultOptions.auditContext,
                {
                  metadata: {
                    model,
                    affectedCount: result.count,
                    updateData: (this as any).sanitizeAuditData(args.data || {}),
                    whereClause: args.where
                  }
                }
              )
            }
          }
          
          return result
        },
        
        async delete({ model, operation, args, query }) {
          // Get the data before deletion for audit
          let dataToDelete = {}
          if (args.where?.id) {
            try {
              dataToDelete = await (this as any).findUnique({ where: args.where })
            } catch (error) {
              // Continue if we can't fetch the data
            }
          }
          
          const result = await query(args)
          
          // Audit the delete operation
          if (!EXCLUDED_MODELS.has(model.toLowerCase())) {
            await (this as any).$audit('delete', dataToDelete, args.where)
          }
          
          return result
        },
        
        async deleteMany({ model, operation, args, query }) {
          // For deleteMany, we should log affected records if possible
          let affectedRecords: any[] = []
          try {
            affectedRecords = await (this as any).findMany({ where: args.where })
          } catch (error) {
            // Continue if we can't fetch the data
          }
          
          const result = await query(args)
          
          // Log bulk delete operation
          if (!EXCLUDED_MODELS.has(model.toLowerCase())) {
            const entityType = MODEL_TO_ENTITY_MAP[model.toLowerCase()]
            if (entityType) {
              const auditService = getAuditService(this as any)
              await auditService.logBulkAction(
                'bulk_delete',
                entityType,
                affectedRecords.map(r => r.id || 'unknown'),
                defaultOptions.auditContext,
                {
                  metadata: {
                    model,
                    affectedCount: result.count,
                    whereClause: args.where,
                    deletedRecords: affectedRecords.map(r => (this as any).sanitizeAuditData(r))
                  }
                }
              )
            }
          }
          
          return result
        }
      }
    }
  })
}

/**
 * Enhanced Prisma client with audit capabilities
 */
export function createAuditablePrismaClient(options: PrismaAuditOptions = {}) {
  const prisma = new PrismaClient()
  const auditExtension = createPrismaAuditExtension(options)
  
  return prisma.$extends(auditExtension)
}

/**
 * Set audit context for the current request/operation
 */
export function withAuditContext<T>(
  prismaClient: any,
  context: AuditContext,
  operation: (client: any) => Promise<T>
): Promise<T> {
  // Create a new client instance with the audit context
  const contextualClient = prismaClient.$extends(
    createPrismaAuditExtension({ ...defaultOptions, auditContext: context })
  )
  
  return operation(contextualClient)
}

export default createPrismaAuditExtension